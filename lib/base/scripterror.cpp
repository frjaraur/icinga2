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

#include "base/scripterror.hpp"
#include <sstream>

using namespace icinga;

ScriptError::ScriptError(const String& message)
	: m_Message(message)
{ }

ScriptError::ScriptError(const String& message, const DebugInfo& di)
	: m_Message(message), m_DebugInfo(di)
{ }

ScriptError::~ScriptError(void) throw()
{ }

const char *ScriptError::what(void) const throw()
{
	return m_Message.CStr();
}

DebugInfo ScriptError::GetDebugInfo(void) const
{
	return m_DebugInfo;
}

