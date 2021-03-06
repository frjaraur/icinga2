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

#ifndef SCRIPTERROR_H
#define SCRIPTERROR_H

#include "base/i2-base.hpp"
#include "base/debuginfo.hpp"
#include "base/exception.hpp"

namespace icinga
{

/*
 * @ingroup base
 */
class I2_BASE_API ScriptError : virtual public user_error
{
public:
	ScriptError(const String& message);
	ScriptError(const String& message, const DebugInfo& di);
	~ScriptError(void) throw();

	virtual const char *what(void) const throw();

	DebugInfo GetDebugInfo(void) const;

private:
	String m_Message;
	DebugInfo m_DebugInfo;
};

}

#endif /* SCRIPTERROR_H */
