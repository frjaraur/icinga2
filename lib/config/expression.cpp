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

#include "config/expression.hpp"
#include "config/configitem.hpp"
#include "config/vmops.hpp"
#include "base/array.hpp"
#include "base/json.hpp"
#include "base/object.hpp"
#include "base/logger.hpp"
#include <boost/foreach.hpp>
#include <boost/exception_ptr.hpp>
#include <boost/exception/errinfo_nested_exception.hpp>

using namespace icinga;

Expression::~Expression(void)
{ }

Value Expression::Evaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	try {
#ifdef _DEBUG
/*		std::ostringstream msgbuf;
		ShowCodeFragment(msgbuf, GetDebugInfo(), false);
		Log(LogDebug, "Expression")
			<< "Executing:\n" << msgbuf.str();*/
#endif /* _DEBUG */

		return DoEvaluate(frame, dhint);
	} catch (const InterruptExecutionError&) {
		throw;
	} catch (const ScriptError& ex) {
		throw;
	} catch (const std::exception& ex) {
		BOOST_THROW_EXCEPTION(ScriptError("Error while evaluating expression: " + String(ex.what()), GetDebugInfo())
		    << boost::errinfo_nested_exception(boost::current_exception()));
	}
}

const DebugInfo& Expression::GetDebugInfo(void) const
{
	static DebugInfo debugInfo;
	return debugInfo;
}

std::vector<Expression *> icinga::MakeIndexer(const String& index1)
{
	std::vector<Expression *> result;
	result.push_back(new VariableExpression(index1));
	return result;
}

void DictExpression::MakeInline(void)
{
	m_Inline = true;
}

LiteralExpression::LiteralExpression(const Value& value)
	: m_Value(value)
{ }

Value LiteralExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Value;
}

const DebugInfo& DebuggableExpression::GetDebugInfo(void) const
{
	return m_DebugInfo;
}

Value VariableExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return VMOps::Variable(frame, m_Variable, GetDebugInfo());
}

Value NegateExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return ~(long)m_Operand->Evaluate(frame);
}

Value LogicalNegateExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return !m_Operand->Evaluate(frame).ToBool();
}

Value AddExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) + m_Operand2->Evaluate(frame);
}

Value SubtractExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) - m_Operand2->Evaluate(frame);
}

Value MultiplyExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) * m_Operand2->Evaluate(frame);
}

Value DivideExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) / m_Operand2->Evaluate(frame);
}

Value ModuloExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return (long)m_Operand1->Evaluate(frame) % (long)m_Operand2->Evaluate(frame);
}

Value XorExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return (long)m_Operand1->Evaluate(frame) ^ (long)m_Operand2->Evaluate(frame);
}

Value BinaryAndExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) & m_Operand2->Evaluate(frame);
}

Value BinaryOrExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) | m_Operand2->Evaluate(frame);
}

Value ShiftLeftExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) << m_Operand2->Evaluate(frame);
}

Value ShiftRightExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) >> m_Operand2->Evaluate(frame);
}

Value EqualExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) == m_Operand2->Evaluate(frame);
}

Value NotEqualExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) != m_Operand2->Evaluate(frame);
}

Value LessThanExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) < m_Operand2->Evaluate(frame);
}

Value GreaterThanExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) > m_Operand2->Evaluate(frame);
}

Value LessThanOrEqualExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) <= m_Operand2->Evaluate(frame);
}

Value GreaterThanOrEqualExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame) >= m_Operand2->Evaluate(frame);
}

Value InExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	Value right = m_Operand2->Evaluate(frame);

	if (right.IsEmpty())
		return false;
	else if (!right.IsObjectType<Array>())
		BOOST_THROW_EXCEPTION(ScriptError("Invalid right side argument for 'in' operator: " + JsonEncode(right), GetDebugInfo()));

	Value left = m_Operand1->Evaluate(frame);

	Array::Ptr arr = right;
	return arr->Contains(left);
}

Value NotInExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	Value right = m_Operand2->Evaluate(frame);

	if (right.IsEmpty())
		return true;
	else if (!right.IsObjectType<Array>())
		BOOST_THROW_EXCEPTION(ScriptError("Invalid right side argument for 'in' operator: " + JsonEncode(right), GetDebugInfo()));

	Value left = m_Operand1->Evaluate(frame);

	Array::Ptr arr = right;
	return !arr->Contains(left);
}

Value LogicalAndExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame).ToBool() && m_Operand2->Evaluate(frame).ToBool();
}

Value LogicalOrExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return m_Operand1->Evaluate(frame).ToBool() || m_Operand2->Evaluate(frame).ToBool();
}

Value FunctionCallExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	Value self, vfunc;

	if (!m_IName.empty()) {
		Value result = m_IName[0]->Evaluate(frame);

		if (m_IName.size() == 2)
			self = result;

		for (int i = 1; i < m_IName.size(); i++) {
			if (result.IsEmpty())
				return Empty;

			Value index = m_IName[i]->Evaluate(frame);
			result = VMOps::GetField(result, index, GetDebugInfo());

			if (i == m_IName.size() - 2)
				self = result;
		}

		vfunc= result;
	}

	if (m_FName)
		vfunc = m_FName->Evaluate(frame);

	if (!vfunc.IsObjectType<ScriptFunction>())
		BOOST_THROW_EXCEPTION(ScriptError("Argument is not a callable object.", GetDebugInfo()));

	ScriptFunction::Ptr func = vfunc;

	std::vector<Value> arguments;
	BOOST_FOREACH(Expression *arg, m_Args) {
		arguments.push_back(arg->Evaluate(frame));
	}

	return VMOps::FunctionCall(frame, self, func, arguments);
}

Value ArrayExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	Array::Ptr result = new Array();

	BOOST_FOREACH(Expression *aexpr, m_Expressions) {
		result->Add(aexpr->Evaluate(frame));
	}

	return result;
}

Value DictExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	ScriptFrame *dframe;
	ScriptFrame rframe;

	if (!m_Inline) {
		dframe = &rframe;
		rframe.Locals = frame.Locals;
		rframe.Self = new Dictionary();
	} else {
		dframe = &frame;
	}

	Value result;

	BOOST_FOREACH(Expression *aexpr, m_Expressions) {
		result = aexpr->Evaluate(*dframe, dhint);
	}

	if (m_Inline)
		return result;
	else
		return dframe->Self;
}

Value SetExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	DebugHint *psdhint = dhint;
	DebugHint sdhint;

	Value parent, object;
	String index;

	for (Array::SizeType i = 0; i < m_Indexer.size(); i++) {
		Expression *indexExpr = m_Indexer[i];

		String tempindex;

		if (i == 0) {
			VariableExpression *vexpr = dynamic_cast<VariableExpression *>(indexExpr);

			if (!vexpr) {
				object = indexExpr->Evaluate(frame, dhint);

				if (!object)
					BOOST_THROW_EXCEPTION(ScriptError("Left-hand side argument must not be null.", GetDebugInfo()));

				continue;
			}

			tempindex = vexpr->GetVariable();
		} else
			tempindex = indexExpr->Evaluate(frame, dhint);

		if (psdhint) {
			sdhint = psdhint->GetChild(tempindex);
			psdhint = &sdhint;
		}

		if (i == 0) {
			if (m_Local)
				parent = frame.Locals;
			else
				parent = frame.Self;
		} else
			parent = object;

		if (i == m_Indexer.size() - 1) {
			index = tempindex;

			/* No need to look up the last indexer's value if this is a direct set */
			if (m_Op == OpSetLiteral)
				break;
		}

		object = VMOps::GetField(parent, tempindex, GetDebugInfo());

		if (i != m_Indexer.size() - 1 && object.IsEmpty()) {
			object = new Dictionary();

			VMOps::SetField(parent, tempindex, object);
		}
	}

	Value right = m_Operand2->Evaluate(frame, dhint);

	if (m_Op != OpSetLiteral) {
		Expression *lhs = MakeLiteral(object);
		Expression *rhs = MakeLiteral(right);

		switch (m_Op) {
			case OpSetAdd:
				right = AddExpression(lhs, rhs, m_DebugInfo).Evaluate(frame, dhint);
				break;
			case OpSetSubtract:
				right = SubtractExpression(lhs, rhs, m_DebugInfo).Evaluate(frame, dhint);
				break;
			case OpSetMultiply:
				right = MultiplyExpression(lhs, rhs, m_DebugInfo).Evaluate(frame, dhint);
				break;
			case OpSetDivide:
				right = DivideExpression(lhs, rhs, m_DebugInfo).Evaluate(frame, dhint);
				break;
			case OpSetModulo:
				right = ModuloExpression(lhs, rhs, m_DebugInfo).Evaluate(frame, dhint);
				break;
			case OpSetXor:
				right = XorExpression(lhs, rhs, m_DebugInfo).Evaluate(frame, dhint);
				break;
			case OpSetBinaryAnd:
				right = BinaryAndExpression(lhs, rhs, m_DebugInfo).Evaluate(frame, dhint);
				break;
			case OpSetBinaryOr:
				right = BinaryOrExpression(lhs, rhs, m_DebugInfo).Evaluate(frame, dhint);
				break;
			default:
				VERIFY(!"Invalid opcode.");
		}
	}

	VMOps::SetField(parent, index, right);

	if (psdhint)
		psdhint->AddMessage("=", m_DebugInfo);

	return right;
}

Value ConditionalExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	if (m_Condition->Evaluate(frame, dhint).ToBool())
		return m_TrueBranch->Evaluate(frame, dhint);
	else if (m_FalseBranch)
		return m_FalseBranch->Evaluate(frame, dhint);

	return Empty;
}

Value ReturnExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	BOOST_THROW_EXCEPTION(InterruptExecutionError(m_Operand->Evaluate(frame)));
}

Value IndexerExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return VMOps::Indexer(frame, m_Indexer, GetDebugInfo());
}

Value ImportExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	String type = VMOps::GetField(frame.Self, "type", GetDebugInfo());
	Value name = m_Name->Evaluate(frame);

	ConfigItem::Ptr item = ConfigItem::GetObject(type, name);

	if (!item)
		BOOST_THROW_EXCEPTION(ScriptError("Import references unknown template: '" + name + "'", GetDebugInfo()));

	item->GetExpression()->Evaluate(frame, dhint);

	return Empty;
}

Value FunctionExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return VMOps::NewFunction(frame, m_Name, m_Args, m_ClosedVars, m_Expression);
}

Value SlotExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return VMOps::NewSlot(frame, m_Signal, m_Slot->Evaluate(frame));
}

Value ApplyExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	return VMOps::NewApply(frame, m_Type, m_Target, m_Name->Evaluate(frame), m_Filter,
	    m_FKVar, m_FVVar, m_FTerm, m_ClosedVars, m_Expression, m_DebugInfo);
}

Value ObjectExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	String name;

	if (m_Name)
		name = m_Name->Evaluate(frame, dhint);

	return VMOps::NewObject(frame, m_Abstract, m_Type, name, m_Filter, m_Zone,
	    m_ClosedVars, m_Expression, m_DebugInfo);
}

Value ForExpression::DoEvaluate(ScriptFrame& frame, DebugHint *dhint) const
{
	Value value = m_Value->Evaluate(frame, dhint);

	return VMOps::For(frame, m_FKVar, m_FVVar, m_Value->Evaluate(frame), m_Expression, m_DebugInfo);
}

