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

#include "base/boolean.hpp"
#include "base/convert.hpp"
#include "base/scriptfunction.hpp"
#include "base/scriptfunctionwrapper.hpp"
#include "base/scriptframe.hpp"

using namespace icinga;

static String BooleanToString(void)
{
	ScriptFrame *vframe = ScriptFrame::GetCurrentFrame();
	bool self = vframe->Self;
	return self ? "true" : "false";
}

Object::Ptr Boolean::GetPrototype(void)
{
	static Dictionary::Ptr prototype;

	if (!prototype) {
		prototype = new Dictionary();
		prototype->Set("to_string", new ScriptFunction(WrapScriptFunction(BooleanToString)));
	}

	return prototype;
}

