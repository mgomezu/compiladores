/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int comment_depth = 0;
int string_length;
%}

/*
 * Define names for regular expressions here.
 */
%x COMMENT
%x S_LINE_COMMENT
%x STRING
%x STRING_ERR

DARROW          =>
ASSIGN		      <-
LE              <=
TYPEID		      [A-Z][A-Za-z0-9_]*
OBJECTID        [a-z][a-zA-Z0-9_]*
CLASS           [Cc][Ll][Aa][Ss][Ss]
ELSE		        [Ee][Ll][Ss][Ee]
FI		          [Ff][Ii]
IF		          [Ii][Ff]
IN		          [Ii][Nn]
INHERITS	      [Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss]
LET		          [Ll][Ee][Tt]
LOOP		        [Ll][Oo][Oo][Pp]
POOL		        [Pp][Oo][Oo][Ll]
THEN		        [Tt][Hh][Ee][Nn]
WHILE		        [Ww][Hh][Ii][Ll][Ee]
CASE		        [Cc][Aa][Ss][Ee]
ESAC		        [Ee][Ss][Aa][Cc]
OF		          [Oo][Ff]
NEW		          [Nn][Ee][Ww]
ISVOID		      [Ii][Ss][Vv][Oo][Ii][Dd]
NOT		          [Nn][Oo][Tt]
INTEGER		      [0-9]+
WHITESPACE  		[ \r\t\v\f]+
PUNCTUATION	    [@;:,\(\)\{\}\+\-\*/=~<\.]
SCOMMENT	      --.* 
MCOMMENT	      [\(\)\*]|[^\(\)\*\n]+
MCOMMENT_START	\(\*
MCOMMENT_END	  \*\)
NEWLINE		      \n
ESCAPE		      \\
ZERO		        \0
%%

 /*
  *  Nested comments
  */


 /*
  *  The multiple-character operators.
  */

{MCOMMENT_START}  {
                    comment_depth++;
                    BEGIN(COMMENT);
                  }
<COMMENT>{MCOMMENT_START} {   comment_depth++; }
<COMMENT>.          {}
<COMMENT>{NEWLINE}         {   curr_lineno++; }
<COMMENT>{MCOMMENT_END}      {
                        comment_depth--;
                        if (comment_depth == 0) {
                            BEGIN(INITIAL);
                        }
                    }
<COMMENT><<EOF>>    {
                        cool_yylval.error_msg = "EOF in comment";
                        BEGIN(INITIAL);
                        return ERROR;
	                }
{MCOMMENT_END}                {
                       cool_yylval.error_msg = "Unmatched *)";
                        BEGIN(INITIAL);
                        return ERROR;
	                }
{SCOMMENT}               {   BEGIN(S_LINE_COMMENT); }
<S_LINE_COMMENT>.   {}
<S_LINE_COMMENT>{NEWLINE}  {
                        curr_lineno++;
                        BEGIN(INITIAL);
                    }
  

{PUNCTUATION} { return yytext[0]; }
{DARROW}  { return (DARROW); }
{ASSIGN}  { return (ASSIGN); }
{CLASS}   { return (CLASS); }
{ELSE}    { return (ELSE); }
{FI}      { return (FI); }
{IF}      { return (IF); }
{IN}      { return (IN); }
{INHERITS} { return (INHERITS); }
{LET}     { return (LET); }
{LOOP}    { return (LOOP); }
{POOL}    { return (POOL); }
{THEN}    { return (THEN); }
{WHILE}   { return (WHILE); }
{CASE}    { return (CASE); }
{ESAC}    { return (ESAC); }
{OF}      { return (OF); }
{NEW}     { return (NEW); }
{ISVOID}  { return (ISVOID); }
{NOT}     { return (NOT); }
{LE}      {   return LE; }

{INTEGER}   { 
            cool_yylval.symbol = inttable.add_string(yytext);
            return INT_CONST;
          }

t[Rr][Uu][Ee]   { 
          cool_yylval.boolean = true;
          return (BOOL_CONST);
            }

f[Aa][Ll][Ss][Ee]   { 
          cool_yylval.boolean = false;
          return (BOOL_CONST);
            }

{TYPEID}  {
            cool_yylval.symbol = stringtable.add_string(yytext);
            return (TYPEID);
          }

{OBJECTID} {
            cool_yylval.symbol = stringtable.add_string(yytext);
            return (OBJECTID);
          }
      
\"        {
            BEGIN(STRING);
            string_length = 0;
          }

<STRING>\"  {
              cool_yylval.symbol = stringtable.add_string(string_buf);
              string_buf[0] = '\0';
              BEGIN(INITIAL);
              return (STR_CONST);
            }

<STRING>{ZERO} {
                cool_yylval.error_msg = "String contains null character";
                string_buf[0] = '\0';
                BEGIN(STRING_ERR);
                return ERROR;
	            }
              
<STRING>\\{ZERO}    {
                    cool_yylval.error_msg = "String contains escaped null character.";
                    string_buf[0] = '\0';
                    BEGIN(STRING_ERR);
                    return ERROR;
	            }

<STRING>{NEWLINE} {
                    cool_yylval.error_msg = "Unterminated string constant";
                    string_buf[0] = '\0';
                    curr_lineno++;
                    BEGIN(INITIAL);
                    return ERROR;
	            }
    
              
<STRING>\\n     {
                    if (string_length + 1 >= MAX_STR_CONST) { 
                      BEGIN(STRING_ERR);
                      string_buf[0] = '\0';
                      cool_yylval.error_msg = "String constant too long";
                      return ERROR;
                     }
                    string_length = string_length + 2;
                    strcat(string_buf, "\n");
	            }

<STRING>\\\n    {
                    if (string_length + 1 >= MAX_STR_CONST) { 
                      BEGIN(STRING_ERR);
                      string_buf[0] = '\0';
                      cool_yylval.error_msg = "String constant too long";
                      return ERROR; 
                    }
                    string_length++;
                    curr_lineno++;
                    strcat(string_buf, "\n");
                }
                
<STRING>\\t     {
                    if (string_length + 1 >= MAX_STR_CONST) { 
                      BEGIN(STRING_ERR);
                      string_buf[0] = '\0';
                      cool_yylval.error_msg = "String constant too long";
                      return ERROR; 
                    }
                    string_length++;
                    strcat(string_buf, "\t");
                }
<STRING>\\b     {
                    if (string_length + 1 >= MAX_STR_CONST) { 
                      BEGIN(STRING_ERR);
                      string_buf[0] = '\0';
                      cool_yylval.error_msg = "String constant too long";
                      return ERROR; 
                    }
                    string_length++;
                    strcat(string_buf, "\b");
	            }
<STRING>\\f     {
                    if (string_length + 1 >= MAX_STR_CONST) { 
                      BEGIN(STRING_ERR);
                      string_buf[0] = '\0';
                      cool_yylval.error_msg = "String constant too long";
                      return ERROR; 
                    }
                    string_length++;
                    strcat(string_buf, "\f");
	            }

<STRING>\\.     {
                    if (string_length + 1 >= MAX_STR_CONST) { 
                      BEGIN(STRING_ERR);
                      string_buf[0] = '\0';
                      cool_yylval.error_msg = "String constant too long";
                      return ERROR; 
                    }
                    string_length++;
                    strcat(string_buf, &strdup(yytext)[1]);
	            }
<STRING><<EOF>> {
	                cool_yylval.error_msg = "EOF in string constant";
	                curr_lineno++;
                    BEGIN(INITIAL);
                    return ERROR;
	            }
<STRING>.       {
                    if (string_length + 1 >= MAX_STR_CONST) { 
                      BEGIN(STRING_ERR);
                      string_buf[0] = '\0';
                      cool_yylval.error_msg = "String constant too long";
                      return ERROR; 
                    }
                    string_length++;
                    strcat(string_buf, yytext);
	            }

<STRING_ERR>\"  {
                    BEGIN(INITIAL);
	            }
<STRING_ERR>\\\n {
	                curr_lineno++;
                    BEGIN(INITIAL);
                }
<STRING_ERR>\n  {
	                curr_lineno++;
                    BEGIN(INITIAL);
	            }
<STRING_ERR>.   {}

{NEWLINE}       {   curr_lineno++; }

{WHITESPACE}     {}

.               {   
	                cool_yylval.error_msg = yytext;
                  return ERROR;
                }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

%%