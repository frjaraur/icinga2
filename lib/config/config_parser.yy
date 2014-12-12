%{
#define YYDEBUG 1
 
/******************************************************************************
 * Icinga 2                                                                   *
 * Copyright (C) 2012-2014 Icinga Development Team (http://www.icinga.org)    *
 *                                                                            *
 * This program is free software; you can redistribute it and/or              *
 * modify it under the terms of the GNU General Public License                *
 * as published by the Free Software Foundation; either version 2             *
 * of the License, or (at your option) any later version.                     *
 *                                                                            *
 * This program is distributed in the hope that it will be useful,            *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of             *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *
 * GNU General Public License for more details.                               *
 *                                                                            *
 * You should have received a copy of the GNU General Public License          *
 * along with this program; if not, write to the Free Software Foundation     *
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.             *
 ******************************************************************************/

#include "config/i2-config.hpp"
#include "config/configitembuilder.hpp"
#include "config/configcompiler.hpp"
#include "config/configcompilercontext.hpp"
#include "config/expression.hpp"
#include "config/applyrule.hpp"
#include "config/objectrule.hpp"
#include "base/value.hpp"
#include "base/utility.hpp"
#include "base/scriptvariable.hpp"
#include "base/exception.hpp"
#include "base/dynamictype.hpp"
#include <sstream>
#include <stack>
#include <boost/foreach.hpp>

#define YYLTYPE icinga::DebugInfo
#define YYERROR_VERBOSE

#define YYLLOC_DEFAULT(Current, Rhs, N)					\
do {									\
	if (N) {							\
		(Current).Path = YYRHSLOC(Rhs, 1).Path;			\
		(Current).FirstLine = YYRHSLOC(Rhs, 1).FirstLine;	\
		(Current).FirstColumn = YYRHSLOC(Rhs, 1).FirstColumn;	\
		(Current).LastLine = YYRHSLOC(Rhs, N).LastLine;		\
		(Current).LastColumn = YYRHSLOC(Rhs, N).LastColumn;	\
	} else {							\
		(Current).Path = YYRHSLOC(Rhs, 0).Path;			\
		(Current).FirstLine = (Current).LastLine =		\
		YYRHSLOC(Rhs, 0).LastLine;				\
		(Current).FirstColumn = (Current).LastColumn =		\
		YYRHSLOC(Rhs, 0).LastColumn;				\
	}								\
} while (0)

#define YY_LOCATION_PRINT(file, loc)			\
do {							\
	std::ostringstream msgbuf;			\
	msgbuf << loc;					\
	std::string str = msgbuf.str();			\
	fputs(str.c_str(), file);			\
} while (0)

using namespace icinga;

template<typename T>
static void MakeRBinaryOp(Expression** result, Expression *left, Expression *right, DebugInfo& diLeft, DebugInfo& diRight)
{
	*result = new T(left, right, DebugInfoRange(diLeft, diRight));
}

%}

%pure-parser

%locations
%defines
%error-verbose

%parse-param { std::vector<Expression *> *elist }
%parse-param { ConfigCompiler *context }
%lex-param { void *scanner }

%union {
	char *text;
	double num;
	bool boolean;
	icinga::Expression *expr;
	CombinedSetOp csop;
	std::vector<String> *slist;
	std::vector<Expression *> *elist;
	std::pair<String, Expression *> *cvitem;
	std::map<String, Expression *> *cvlist;
}

%token T_NEWLINE "new-line"
%token <text> T_STRING
%token <text> T_STRING_ANGLE
%token <num> T_NUMBER
%token <boolean> T_BOOLEAN
%token T_NULL
%token <text> T_IDENTIFIER

%token <csop> T_SET "= (T_SET)"
%token <csop> T_SET_ADD "+= (T_SET_ADD)"
%token <csop> T_SET_SUBTRACT "-= (T_SET_SUBTRACT)"
%token <csop> T_SET_MULTIPLY "*= (T_SET_MULTIPLY)"
%token <csop> T_SET_DIVIDE "/= (T_SET_DIVIDE)"
%token <csop> T_SET_MODULO "%= (T_SET_MODULO)"
%token <csop> T_SET_XOR "^= (T_SET_XOR)"
%token <csop> T_SET_BINARY_AND "&= (T_SET_BINARY_AND)"
%token <csop> T_SET_BINARY_OR "|= (T_SET_BINARY_OR)"

%token T_SHIFT_LEFT "<< (T_SHIFT_LEFT)"
%token T_SHIFT_RIGHT ">> (T_SHIFT_RIGHT)"
%token T_EQUAL "== (T_EQUAL)"
%token T_NOT_EQUAL "!= (T_NOT_EQUAL)"
%token T_IN "in (T_IN)"
%token T_NOT_IN "!in (T_NOT_IN)"
%token T_LOGICAL_AND "&& (T_LOGICAL_AND)"
%token T_LOGICAL_OR "|| (T_LOGICAL_OR)"
%token T_LESS_THAN_OR_EQUAL "<= (T_LESS_THAN_OR_EQUAL)"
%token T_GREATER_THAN_OR_EQUAL ">= (T_GREATER_THAN_OR_EQUAL)"
%token T_PLUS "+ (T_PLUS)"
%token T_MINUS "- (T_MINUS)"
%token T_MULTIPLY "* (T_MULTIPLY)"
%token T_DIVIDE_OP "/ (T_DIVIDE_OP)"
%token T_MODULO "% (T_MODULO)"
%token T_XOR "^ (T_XOR)"
%token T_BINARY_AND "& (T_BINARY_AND)"
%token T_BINARY_OR "| (T_BINARY_OR)"
%token T_LESS_THAN "< (T_LESS_THAN)"
%token T_GREATER_THAN "> (T_GREATER_THAN)"

%token T_CONST "const (T_CONST)"
%token T_LOCAL "local (T_LOCAL)"
%token T_USE "use (T_USE)"
%token T_OBJECT "object (T_OBJECT)"
%token T_TEMPLATE "template (T_TEMPLATE)"
%token T_INCLUDE "include (T_INCLUDE)"
%token T_INCLUDE_RECURSIVE "include_recursive (T_INCLUDE_RECURSIVE)"
%token T_LIBRARY "library (T_LIBRARY)"
%token T_INHERITS "inherits (T_INHERITS)"
%token T_APPLY "apply (T_APPLY)"
%token T_TO "to (T_TO)"
%token T_WHERE "where (T_WHERE)"
%token T_IMPORT "import (T_IMPORT)"
%token T_ASSIGN "assign (T_ASSIGN)"
%token T_IGNORE "ignore (T_IGNORE)"
%token T_FUNCTION "function (T_FUNCTION)"
%token T_RETURN "return (T_RETURN)"
%token T_FOR "for (T_FOR)"
%token T_SIGNAL "signal (T_SIGNAL)"
%token T_IF "if (T_IF)"
%token T_ELSE "else (T_ELSE)"
%token T_FOLLOWS "=> (T_FOLLOWS)"

%type <text> identifier
%type <elist> rterm_items
%type <elist> rterm_items_inner
%type <slist> identifier_items
%type <slist> identifier_items_inner
%type <elist> indexer
%type <elist> indexer_items
%type <expr> indexer_item
%type <csop> combined_set_op
%type <elist> statements
%type <elist> lterm_items
%type <elist> lterm_items_inner
%type <expr> rterm
%type <expr> rterm_without_indexer
%type <expr> rterm_array
%type <expr> rterm_scope
%type <expr> lterm
%type <expr> object
%type <expr> apply
%type <expr> optional_rterm
%type <text> target_type_specifier
%type <cvlist> use_specifier
%type <cvlist> use_specifier_items
%type <cvitem> use_specifier_item
%type <num> object_declaration

%right T_INCLUDE T_INCLUDE_RECURSIVE T_OBJECT T_TEMPLATE T_APPLY T_IMPORT T_ASSIGN T_IGNORE T_WHERE
%right T_FUNCTION T_SIGNAL T_FOR
%left T_LOGICAL_OR
%left T_LOGICAL_AND
%left T_LOCAL T_RETURN
%left T_IDENTIFIER
%left T_SET T_SET_ADD T_SET_SUBTRACT T_SET_MULTIPLY T_SET_DIVIDE T_SET_MODULO T_SET_XOR T_SET_BINARY_AND T_SET_BINARY_OR
%nonassoc T_EQUAL T_NOT_EQUAL
%nonassoc T_LESS_THAN T_LESS_THAN_OR_EQUAL T_GREATER_THAN T_GREATER_THAN_OR_EQUAL
%left T_BINARY_OR
%left T_XOR T_MODULO
%left T_BINARY_AND
%left T_IN T_NOT_IN
%left T_SHIFT_LEFT T_SHIFT_RIGHT
%left T_PLUS T_MINUS
%left T_MULTIPLY T_DIVIDE_OP
%left UNARY_MINUS
%right '!' '~'
%left '.' '(' '['
%right ';' ','
%right T_NEWLINE
%{

int yylex(YYSTYPE *lvalp, YYLTYPE *llocp, void *scanner);

void yyerror(YYLTYPE *locp, std::vector<Expression *> *, ConfigCompiler *, const char *err)
{
	BOOST_THROW_EXCEPTION(ScriptError(err, *locp));
}

int yyparse(std::vector<Expression *> *elist, ConfigCompiler *context);

Expression *ConfigCompiler::Compile(void)
{
	std::vector<Expression *> elist;

	if (yyparse(&elist, this) != 0)
		return NULL;

	DictExpression *expr = new DictExpression(elist);
	expr->MakeInline();
	return expr;
}

#define scanner (context->GetScanner())

%}

%%
script: statements
	{
		elist->swap(*$1);
		delete $1;
	}
	;

statements: newlines lterm_items newlines
	{
		$$ = $2;
	}
	| newlines lterm_items
	{
		$$ = $2;
	}
	| lterm_items newlines
	{
		$$ = $1;
	}
	| lterm_items
	{
		$$ = $1;
	}
	;

lterm_items: /* empty */
	{
		$$ = new std::vector<Expression *>();
	}
	| lterm_items_inner
	{
		$$ = $1;
	}
	| lterm_items_inner sep
	{
		$$ = $1;
	}
	;

lterm_items_inner: lterm
	{
		$$ = new std::vector<Expression *>();
		$$->push_back($1);
	}
	| lterm_items_inner sep lterm
	{
		if ($1)
			$$ = $1;
		else
			$$ = new std::vector<Expression *>();

		if ($3)
			$$->push_back($3);
	}
	;

library: T_LIBRARY T_STRING
	{
		context->HandleLibrary($2);
		free($2);
	}
	;

constant: T_CONST identifier T_SET rterm
	{
		ScriptFrame frame;
		ScriptVariable::Ptr sv = ScriptVariable::Set($2, $4->Evaluate(frame));
		free($2);
		delete $4;

		sv->SetConstant(true);
	}
	;

identifier: T_IDENTIFIER
	| T_STRING
	{
		$$ = $1;
	}
	;

object:
	{
		context->m_ObjectAssign.push(true);
		context->m_SeenAssign.push(false);
		context->m_Assign.push(NULL);
		context->m_Ignore.push(NULL);
	}
	object_declaration identifier rterm use_specifier rterm_scope
	{
		context->m_ObjectAssign.pop();

		bool abstract = $2;

		String type = $3;
		free($3);

		DictExpression *exprl = dynamic_cast<DictExpression *>($6);
		exprl->MakeInline();

		bool seen_assign = context->m_SeenAssign.top();
		context->m_SeenAssign.pop();

		Expression *ignore = context->m_Ignore.top();
		context->m_Ignore.pop();

		Expression *assign = context->m_Assign.top();
		context->m_Assign.pop();

		Expression *filter = NULL;

		if (seen_assign) {
			if (!ObjectRule::IsValidSourceType(type))
				BOOST_THROW_EXCEPTION(ScriptError("object rule 'assign' cannot be used for type '" + type + "'", DebugInfoRange(@2, @3)));

			if (ignore) {
				Expression *rex = new LogicalNegateExpression(ignore, DebugInfoRange(@2, @5));

				filter = new LogicalAndExpression(assign, rex, DebugInfoRange(@2, @5));
			} else
				filter = assign;
		}

		$$ = new ObjectExpression(abstract, type, $4, filter, context->GetZone(), $5, exprl, DebugInfoRange(@2, @5));
	}
	;

object_declaration: T_OBJECT
	{
		$$ = false;
	}
	| T_TEMPLATE
	{
		$$ = true;
	}
	;

identifier_items: identifier_items_inner
	{
		$$ = $1;
	}
	| identifier_items_inner ','
	{
		$$ = $1;
	}
	;

identifier_items_inner: /* empty */
	{
		$$ = new std::vector<String>();
	}
	| identifier
	{
		$$ = new std::vector<String>();
		$$->push_back($1);
		free($1);
	}
	| identifier_items_inner ',' identifier
	{
		if ($1)
			$$ = $1;
		else
			$$ = new std::vector<String>();

		$$->push_back($3);
		free($3);
	}
	;

indexer: rterm_without_indexer indexer_items
	{
		$$ = $2;
		$$->insert($$->begin(), $1);
	}
	;

indexer_items: indexer_item
	{
		$$ = new std::vector<Expression *>();
		$$->push_back($1);
	}
	| indexer_items indexer_item
	{
		$$ = $1;
		$$->push_back($2);
	}
	;

indexer_item: '.' identifier
	{
		$$ = MakeLiteral($2);
		free($2);
	}
	| '[' rterm ']'
	{
		$$ = $2;
	}
	;

combined_set_op: T_SET
	| T_SET_ADD
	| T_SET_SUBTRACT
	| T_SET_MULTIPLY
	| T_SET_DIVIDE
	| T_SET_MODULO
	| T_SET_XOR
	| T_SET_BINARY_AND
	| T_SET_BINARY_OR
	{
		$$ = $1;
	}
	;

lterm: library
	{
		$$ = MakeLiteral(); // ASTify this
	}
	| constant
	{
		$$ = MakeLiteral(); // ASTify this
	}
	| T_LOCAL indexer combined_set_op rterm
	{
		$$ = new SetExpression(*$2, $3, $4, true, DebugInfoRange(@1, @4));
		delete $2;
	}
	| indexer combined_set_op rterm
	{
		$$ = new SetExpression(*$1, $2, $3, false, DebugInfoRange(@1, @3));
		delete $1;
	}
	| T_LOCAL identifier combined_set_op rterm
	{
		$$ = new SetExpression(MakeIndexer($2), $3, $4, true, DebugInfoRange(@1, @4));
		free($2);
	}
	| identifier combined_set_op rterm
	{
		$$ = new SetExpression(MakeIndexer($1), $2, $3, false, DebugInfoRange(@1, @3));
		free($1);
	}
	| T_INCLUDE T_STRING
	{
		$$ = context->HandleInclude($2, false, DebugInfoRange(@1, @2));
		free($2);
	}
	| T_INCLUDE T_STRING_ANGLE
	{
		$$ = context->HandleInclude($2, true, DebugInfoRange(@1, @2));
		free($2);
	}
	| T_INCLUDE_RECURSIVE T_STRING
	{
		$$ = context->HandleIncludeRecursive($2, "*.conf", DebugInfoRange(@1, @2));
		free($2);
	}
	| T_INCLUDE_RECURSIVE T_STRING ',' T_STRING
	{
		$$ = context->HandleIncludeRecursive($2, $4, DebugInfoRange(@1, @4));
		free($2);
		free($4);
	}
	| T_IMPORT rterm
	{
		$$ = new ImportExpression($2, DebugInfoRange(@1, @2));
	}
	| T_ASSIGN T_WHERE rterm
	{
		if ((context->m_Apply.empty() || !context->m_Apply.top()) && (context->m_ObjectAssign.empty() || !context->m_ObjectAssign.top()))
			BOOST_THROW_EXCEPTION(ScriptError("'assign' keyword not valid in this context.", DebugInfoRange(@1, @3)));

		context->m_SeenAssign.top() = true;

		if (context->m_Assign.top())
			context->m_Assign.top() = new LogicalOrExpression(context->m_Assign.top(), $3, DebugInfoRange(@1, @3));
		else
			context->m_Assign.top() = $3;

		$$ = MakeLiteral();
	}
	| T_IGNORE T_WHERE rterm
	{
		if ((context->m_Apply.empty() || !context->m_Apply.top()) && (context->m_ObjectAssign.empty() || !context->m_ObjectAssign.top()))
			BOOST_THROW_EXCEPTION(ScriptError("'ignore' keyword not valid in this context.", DebugInfoRange(@1, @3)));

		if (context->m_Ignore.top())
			context->m_Ignore.top() = new LogicalOrExpression(context->m_Ignore.top(), $3, DebugInfoRange(@1, @3));
		else
			context->m_Ignore.top() = $3;

		$$ = MakeLiteral();
	}
	| T_RETURN rterm
	{
		$$ = new ReturnExpression($2, DebugInfoRange(@1, @2));
	}
	| apply
	{
		$$ = $1;
	}
	| object
	{
		$$ = $1;
	}
	| T_SIGNAL identifier T_SET_ADD rterm
	{
		$$ = new SlotExpression($2, $4, DebugInfoRange(@1, @4));
		free($2);
	}
	| T_FOR '(' identifier T_FOLLOWS identifier T_IN rterm ')' rterm_scope
	{
		DictExpression *aexpr = dynamic_cast<DictExpression *>($9);
		aexpr->MakeInline();

		$$ = new ForExpression($3, $5, $7, aexpr, DebugInfoRange(@1, @9));
		free($3);
		free($5);
	}
	| T_FOR '(' identifier T_IN rterm ')' rterm_scope
	{
		DictExpression *aexpr = dynamic_cast<DictExpression *>($7);
		aexpr->MakeInline();

		$$ = new ForExpression($3, "", $5, aexpr, DebugInfoRange(@1, @7));
		free($3);
	}
	| T_IF '(' rterm ')' rterm_scope
	{
		DictExpression *atrue = dynamic_cast<DictExpression *>($5);
		atrue->MakeInline();

		$$ = new ConditionalExpression($3, atrue, NULL, DebugInfoRange(@1, @5));
	}
	| T_IF '(' rterm ')' rterm_scope T_ELSE rterm_scope
	{
		DictExpression *atrue = dynamic_cast<DictExpression *>($5);
		atrue->MakeInline();

		DictExpression *afalse = dynamic_cast<DictExpression *>($7);
		afalse->MakeInline();

		$$ = new ConditionalExpression($3, atrue, afalse, DebugInfoRange(@1, @7));
	}
	| rterm
	{
		$$ = $1;
	}
	;
	
rterm_items: /* empty */
	{
		$$ = new std::vector<Expression *>();
	}
	| rterm_items_inner
	{
		$$ = $1;
	}
	| rterm_items_inner arraysep
	{
		$$ = $1;
	}
	;

rterm_items_inner: rterm
	{
		$$ = new std::vector<Expression *>();
		$$->push_back($1);
	}
	| rterm_items_inner arraysep rterm
	{
		$$ = $1;
		$$->push_back($3);
	}
	;

rterm_array: '[' newlines rterm_items newlines ']'
	{
		$$ = new ArrayExpression(*$3, DebugInfoRange(@1, @5));
		delete $3;
	}
	| '[' newlines rterm_items ']'
	{
		$$ = new ArrayExpression(*$3, DebugInfoRange(@1, @4));
		delete $3;
	}
	| '[' rterm_items newlines ']'
	{
		$$ = new ArrayExpression(*$2, DebugInfoRange(@1, @4));
		delete $2;
	}
	| '[' rterm_items ']'
	{
		$$ = new ArrayExpression(*$2, DebugInfoRange(@1, @3));
		delete $2;
	}
	;

rterm_scope: '{' statements '}'
	{
		$$ = new DictExpression(*$2, DebugInfoRange(@1, @3));
		delete $2;
	}
	;

rterm: rterm_without_indexer
	{
		$$ = $1;
	}
	| indexer
	{
		$$ = new IndexerExpression(*$1, @1);
		delete $1;
	}
	;

rterm_without_indexer: T_STRING
	{
		$$ = MakeLiteral($1);
		free($1);
	}
	| T_NUMBER
	{
		$$ = MakeLiteral($1);
	}
	| T_BOOLEAN
	{
		$$ = MakeLiteral($1);
	}
	| T_NULL
	{
		$$ = MakeLiteral();
	}
	| indexer '(' rterm_items ')'
	{
		$$ = new FunctionCallExpression(*$1, NULL, *$3, DebugInfoRange(@1, @4));
		delete $1;
		delete $3;
	}
	| rterm '(' rterm_items ')'
	{
		$$ = new FunctionCallExpression(MakeIndexer("this"), $1, *$3, DebugInfoRange(@1, @4));
		delete $3;
	}
	| T_IDENTIFIER
	{
		$$ = new VariableExpression($1, @1);
		free($1);
	}
	| '!' rterm
	{
		$$ = new LogicalNegateExpression($2, DebugInfoRange(@1, @2));
	}
	| '~' rterm
	{
		$$ = new NegateExpression($2, DebugInfoRange(@1, @2));
	}
	| T_MINUS rterm %prec UNARY_MINUS
	{
		$$ = new SubtractExpression(MakeLiteral(0), $2, DebugInfoRange(@1, @2));
	}
	| rterm_array
	{
		$$ = $1;
	}
	| rterm_scope
	{
		$$ = $1;
	}
	| '('
	{
		context->m_IgnoreNewlines++;
	}
	rterm ')'
	{
		context->m_IgnoreNewlines--;
		$$ = $3;
	}
	| rterm T_LOGICAL_OR rterm { MakeRBinaryOp<LogicalOrExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_LOGICAL_AND rterm { MakeRBinaryOp<LogicalAndExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_BINARY_OR rterm { MakeRBinaryOp<BinaryOrExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_BINARY_AND rterm { MakeRBinaryOp<BinaryAndExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_IN rterm { MakeRBinaryOp<InExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_NOT_IN rterm { MakeRBinaryOp<NotInExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_EQUAL rterm { MakeRBinaryOp<EqualExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_NOT_EQUAL rterm { MakeRBinaryOp<NotEqualExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_LESS_THAN rterm { MakeRBinaryOp<LessThanExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_LESS_THAN_OR_EQUAL rterm { MakeRBinaryOp<LessThanOrEqualExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_GREATER_THAN rterm { MakeRBinaryOp<GreaterThanExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_GREATER_THAN_OR_EQUAL rterm { MakeRBinaryOp<GreaterThanOrEqualExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_SHIFT_LEFT rterm { MakeRBinaryOp<ShiftLeftExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_SHIFT_RIGHT rterm { MakeRBinaryOp<ShiftRightExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_PLUS rterm { MakeRBinaryOp<AddExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_MINUS rterm { MakeRBinaryOp<SubtractExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_MULTIPLY rterm { MakeRBinaryOp<MultiplyExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_DIVIDE_OP rterm { MakeRBinaryOp<DivideExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_MODULO rterm { MakeRBinaryOp<ModuloExpression>(&$$, $1, $3, @1, @3); }
	| rterm T_XOR rterm { MakeRBinaryOp<XorExpression>(&$$, $1, $3, @1, @3); }
	| T_FUNCTION identifier '(' identifier_items ')' use_specifier rterm_scope
	{
		DictExpression *aexpr = dynamic_cast<DictExpression *>($7);
		aexpr->MakeInline();

		$$ = new FunctionExpression($2, *$4, $6, aexpr, DebugInfoRange(@1, @6));
		free($2);
		delete $4;
	}
	| T_FUNCTION '(' identifier_items ')' use_specifier rterm_scope
	{
		DictExpression *aexpr = dynamic_cast<DictExpression *>($6);
		aexpr->MakeInline();

		$$ = new FunctionExpression("", *$3, $5, aexpr, DebugInfoRange(@1, @5));
		delete $3;
	}
	;

target_type_specifier: /* empty */
	{
		$$ = strdup("");
	}
	| T_TO identifier
	{
		$$ = $2;
	}
	;

use_specifier: /* empty */
	{
		$$ = NULL;
	}
	| T_USE '(' use_specifier_items ')'
	{
		$$ = $3;
	}
	;

use_specifier_items: use_specifier_item
	{
		$$ = new std::map<String, Expression *>();
		$$->insert(*$1);
		delete $1;
	}
	| use_specifier_items ',' use_specifier_item
	{
		$$ = $1;
		$$->insert(*$3);
		delete $3;
	}
	;

use_specifier_item: identifier
	{
		$$ = new std::pair<String, Expression *>($1, new VariableExpression($1, @1));
	}
	| identifier T_SET rterm
	{
		$$ = new std::pair<String, Expression *>($1, $3);
	}
	;

apply_for_specifier: /* empty */
	| T_FOR '(' identifier T_FOLLOWS identifier T_IN rterm ')'
	{
		context->m_FKVar.top() = $3;
		free($3);

		context->m_FVVar.top() = $5;
		free($5);

		context->m_FTerm.top() = $7;
	}
	| T_FOR '(' identifier T_IN rterm ')'
	{
		context->m_FKVar.top() = $3;
		free($3);

		context->m_FVVar.top() = "";

		context->m_FTerm.top() = $5;
	}
	;

optional_rterm: /* empty */
	{
		$$ = MakeLiteral();
	}
	| rterm
	{
		$$ = $1;
	}
	;

apply:
	{
		context->m_Apply.push(true);
		context->m_SeenAssign.push(false);
		context->m_Assign.push(NULL);
		context->m_Ignore.push(NULL);
		context->m_FKVar.push("");
		context->m_FVVar.push("");
		context->m_FTerm.push(NULL);
	}
	T_APPLY identifier optional_rterm apply_for_specifier target_type_specifier use_specifier rterm_scope
	{
		context->m_Apply.pop();

		String type = $3;
		free($3);
		String target = $6;
		free($6);

		if (!ApplyRule::IsValidSourceType(type))
			BOOST_THROW_EXCEPTION(ScriptError("'apply' cannot be used with type '" + type + "'", DebugInfoRange(@2, @3)));

		if (!ApplyRule::IsValidTargetType(type, target)) {
			if (target == "") {
				std::vector<String> types = ApplyRule::GetTargetTypes(type);
				String typeNames;

				for (std::vector<String>::size_type i = 0; i < types.size(); i++) {
					if (typeNames != "") {
						if (i == types.size() - 1)
							typeNames += " or ";
						else
							typeNames += ", ";
					}

					typeNames += "'" + types[i] + "'";
				}

				BOOST_THROW_EXCEPTION(ScriptError("'apply' target type is ambiguous (can be one of " + typeNames + "): use 'to' to specify a type", DebugInfoRange(@2, @3)));
			} else
				BOOST_THROW_EXCEPTION(ScriptError("'apply' target type '" + target + "' is invalid", DebugInfoRange(@2, @5)));
		}

		DictExpression *exprl = dynamic_cast<DictExpression *>($8);
		exprl->MakeInline();

		// assign && !ignore
		if (!context->m_SeenAssign.top())
			BOOST_THROW_EXCEPTION(ScriptError("'apply' is missing 'assign'", DebugInfoRange(@2, @3)));

		context->m_SeenAssign.pop();

		Expression *ignore = context->m_Ignore.top();
		context->m_Ignore.pop();

		Expression *assign = context->m_Assign.top();
		context->m_Assign.pop();

		Expression *filter;

		if (ignore) {
			Expression *rex = new LogicalNegateExpression(ignore, DebugInfoRange(@2, @5));

			filter = new LogicalAndExpression(assign, rex, DebugInfoRange(@2, @5));
		} else
			filter = assign;

		String fkvar = context->m_FKVar.top();
		context->m_FKVar.pop();

		String fvvar = context->m_FVVar.top();
		context->m_FVVar.pop();

		Expression *fterm = context->m_FTerm.top();
		context->m_FTerm.pop();

		$$ = new ApplyExpression(type, target, $4, filter, fkvar, fvvar, fterm, $7, exprl, DebugInfoRange(@2, @7));
	}
	;

newlines: T_NEWLINE
	| T_NEWLINE newlines
	;

/* required separator */
sep: ',' newlines
	| ','
	| ';' newlines
	| ';'
	| newlines
	;

arraysep: ',' newlines
	| ','
	;

%%
