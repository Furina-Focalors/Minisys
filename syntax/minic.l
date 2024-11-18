D			[0-9]
L			[a-zA-Z_]
H           0x([a-zA-Z0-9])+

%{
// lex file for minic
%}

%%
"//"(.*)(\n)?               { return(_COMMENT); }
"break"			            { return(BREAK); }
"char"                      { return(CHAR); }
"continue"	                { return(CONTINUE); }
"else"			            { return(ELSE); }
"for"			            { return(FOR); }
"if"			            { return(IF); }
"int"			            { return(INT); }
"short"                     { return(SHORT); }
"return"		            { return(RETURN); }
"void"			            { return(VOID); }
"while"			            { return(WHILE); }
{H}                         { return(CONSTANT); }
{L}({L}|{D})*		        { return(IDENTIFIER); }
0|([1-9]{D}*)				{ return(CONSTANT); }
\"(\\.|[^\\"\n])*\"         { return(STRING_LITERAL); }

"+"			        	    { return(ADD_OP); }
"-"			        	    { return(SUB_OP); }
"*"			        	    { return(MUL_OP); }
"/"			        	    { return(DIV_OP); }
"%"                         { return(MOD_OP); }
"++"			            { return(INC_OP); }
"--"			            { return(DEC_OP); }

"<="			            { count(); return(LE_OP); }
">="			            { count(); return(GE_OP); }
"=="			            { count(); return(EQ_OP); }
"!="			            { count(); return(NE_OP); }
"<"			        	    { return(LT_OP); }
">"			        	    { return(GT_OP); }

"&&"			            { return(AND_OP); }
"||"			            { return(OR_OP); }
"!"			        	    { return(NOT_OP); }

"$"                         { return(DOLLAR); }

">>"			            { return(RIGHT_OP); }
"<<"			            { return(LEFT_OP); }
";"		        		    { return(SEMICOLON); }
"{"	            	        { return(LBRACE); }
"}"	          		        { return(RBRACE); }
","			        	    { return(COMMA); }
":"			        	    { return(COLON); }
"="			        	    { return(ASSIGN_OP); }
"(" 		        	    { return(LPAREN); }
")"			        	    { return(RPAREN); }
"["			                { return(LBRACKET); }
"]"	  	        	        { return(RBRACKET); }
"."			        	    { return(DOT); }
"&"			        	    { return(BITAND_OP); }
"~"			        	    { return(BITINV_OP); }
"^"			        	    { return(BITXOR); }
"|"			        	    { return(BITOR); }
[ \t\v\n\f]                 { return (_WHITESPACE); }
.			 	 	        { return(_UNMATCH); }
%%


