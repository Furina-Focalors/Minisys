D			[0-9]
L			[a-zA-Z_]
H           0[xX][a-fA-F0-9]+

%{
#include "ast.h"
#include "minic.tab.h"
%}

%option yylineno

%%
"//"(.*)(\n)?               { /* ignore comments */ }
"break"			            { yylval.node=createASTNode("BREAK",0); return(BREAK); }
"char"                      { yylval.node=createASTNode("CHAR",0); return(CHAR); }
"continue"	                { yylval.node=createASTNode("CONTINUE",0); return(CONTINUE); }
"else"			            { yylval.node=createASTNode("ELSE",0); return(ELSE); }
"for"			            { yylval.node=createASTNode("FOR",0); return(FOR); }
"if"			            { yylval.node=createASTNode("IF",0); return(IF); }
"int"			            { yylval.node=createASTNode("INT",0); return(INT); }
"short"                     { yylval.node=createASTNode("SHORT",0); return(SHORT); }
"return"		            { yylval.node=createASTNode("RETURN",0); return(RETURN); }
"void"			            { yylval.node=createASTNode("VOID",0); return(VOID); }
"while"			            { yylval.node=createASTNode("WHILE",0); return(WHILE); }
{H}                         { yylval.node=createASTNodeForInt(atoi(yytext)); return(INT_CONSTANT); }
{L}({L}|{D})*		        { yylval.node=createASTNode(_strdup(yytext),0); return(IDENTIFIER); }
0|([1-9]{D}*)				{ yylval.node=createASTNodeForInt(atoi(yytext)); return(INT_CONSTANT); }
'\\.'|'[^\\']'              { yylval.node=createASTNodeForChar(yytext[1]); return(CHAR_CONSTANT); }
\"(\\.|[^\\"\n])*\"         { yylval.node=createASTNodeForStr(_strdup(yytext)); return(STRING_LITERAL); }

"+"			        	    { yylval.node=createASTNode("+",0); return(ADD_OP); }
"-"			        	    { yylval.node=createASTNode("-",0); return(SUB_OP); }
"*"			        	    { yylval.node=createASTNode("*",0); return(MUL_OP); }
"/"			        	    { yylval.node=createASTNode("/",0); return(DIV_OP); }
"%"                         { yylval.node=createASTNode("%",0); return(MOD_OP); }
"++"			            { yylval.node=createASTNode("++",0); return(INC_OP); }
"--"			            { yylval.node=createASTNode("--",0); return(DEC_OP); }

"<="			            { yylval.node=createASTNode("<=",0); return(LE_OP); }
">="			            { yylval.node=createASTNode(">=",0); return(GE_OP); }
"=="			            { yylval.node=createASTNode("==",0); return(EQ_OP); }
"!="			            { yylval.node=createASTNode("!=",0); return(NE_OP); }
"<"			        	    { yylval.node=createASTNode("<",0); return(LT_OP); }
">"			        	    { yylval.node=createASTNode(">",0); return(GT_OP); }

"&&"			            { yylval.node=createASTNode("&&",0); return(AND_OP); }
"||"			            { yylval.node=createASTNode("||",0); return(OR_OP); }
"!"			        	    { yylval.node=createASTNode("!",0); return(NOT_OP); }

"$"                         { yylval.node=createASTNode("$",0); return(ADDR_OP); }
">>"			            { yylval.node=createASTNode(">>",0); return(RIGHT_OP); }
"<<"			            { yylval.node=createASTNode("<<",0); return(LEFT_OP); }
"&"			        	    { yylval.node=createASTNode("&",0); return(BITAND_OP); }
"~"			        	    { yylval.node=createASTNode("~",0); return(BITINV_OP); }
"^"			        	    { yylval.node=createASTNode("^",0); return(BITXOR_OP); }
"|"			        	    { yylval.node=createASTNode("|",0); return(BITOR_OP); }

";"		        		    { yylval.node=createASTNode(";",0); return(SEMICOLON); }
"{"	            	        { yylval.node=createASTNode("{",0); return(LBRACE); }
"}"	          		        { yylval.node=createASTNode("}",0); return(RBRACE); }
","			        	    { yylval.node=createASTNode(",",0); return(COMMA); }
":"			        	    { yylval.node=createASTNode(":",0); return(COLON); }
"="			        	    { yylval.node=createASTNode("=",0); return(ASSIGN_OP); }
"(" 		        	    { yylval.node=createASTNode("(",0); return(LPAREN); }
")"			        	    { yylval.node=createASTNode(")",0); return(RPAREN); }
"["			                { yylval.node=createASTNode("[",0); return(LBRACKET); }
"]"	  	        	        { yylval.node=createASTNode("]",0); return(RBRACKET); }
"."			        	    { yylval.node=createASTNode(".",0); return(DOT); }
[ \t\v\n\f]                 { /* ignore whitespaces */ }
.			 	 	        { printf("Unrecognized character '%s' at line %d.\n", yytext, yylineno); return(_UNMATCH); }
%%
