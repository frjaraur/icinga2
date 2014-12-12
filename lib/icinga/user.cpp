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

#include "icinga/user.hpp"
#include "icinga/usergroup.hpp"
#include "icinga/notification.hpp"
#include "icinga/usergroup.hpp"
#include "base/objectlock.hpp"
#include <boost/foreach.hpp>

using namespace icinga;

REGISTER_TYPE(User);

boost::signals2::signal<void (const User::Ptr&, bool, const MessageOrigin&)> User::OnEnableNotificationsChanged;

void User::OnConfigLoaded(void)
{
	DynamicObject::OnConfigLoaded();

	SetTypeFilter(FilterArrayToInt(GetTypes(), ~0));
	SetStateFilter(FilterArrayToInt(GetStates(), ~0));
}

void User::OnAllConfigLoaded(void)
{
	DynamicObject::OnAllConfigLoaded();

	UserGroup::EvaluateObjectRules(this);

	Array::Ptr groups = GetGroups();

	if (groups) {
		groups = groups->ShallowClone();

		ObjectLock olock(groups);

		BOOST_FOREACH(const String& name, groups) {
			UserGroup::Ptr ug = UserGroup::GetByName(name);

			if (ug)
				ug->ResolveGroupMembership(this, true);
		}
	}
}

void User::Stop(void)
{
	DynamicObject::Stop();

	Array::Ptr groups = GetGroups();

	if (groups) {
		ObjectLock olock(groups);

		BOOST_FOREACH(const String& name, groups) {
			UserGroup::Ptr ug = UserGroup::GetByName(name);

			if (ug)
				ug->ResolveGroupMembership(this, false);
		}
	}
}

void User::AddGroup(const String& name)
{
	boost::mutex::scoped_lock lock(m_UserMutex);

	Array::Ptr groups = GetGroups();

	if (groups && groups->Contains(name))
		return;

	if (!groups)
		groups = new Array();

	groups->Add(name);
}

TimePeriod::Ptr User::GetPeriod(void) const
{
	return TimePeriod::GetByName(GetPeriodRaw());
}

void User::Validate(const ValidationUtils& utils) const
{
	ObjectImpl<User>::Validate(utils);

	int sfilter = FilterArrayToInt(GetStates(), 0);

	if ((sfilter & ~(StateFilterUp | StateFilterDown | StateFilterOK | StateFilterWarning | StateFilterCritical | StateFilterUnknown)) != 0) {
		BOOST_THROW_EXCEPTION(ScriptError("Validation failed: State filter is invalid.", GetDebugInfo()));
	}

	int tfilter = FilterArrayToInt(GetTypes(), 0);

	if ((tfilter & ~(1 << NotificationDowntimeStart | 1 << NotificationDowntimeEnd | 1 << NotificationDowntimeRemoved |
	    1 << NotificationCustom | 1 << NotificationAcknowledgement | 1 << NotificationProblem | 1 << NotificationRecovery |
	    1 << NotificationFlappingStart | 1 << NotificationFlappingEnd)) != 0) {
		BOOST_THROW_EXCEPTION(ScriptError("Validation failed: Type filter is invalid.", GetDebugInfo()));
	}
}

int User::GetModifiedAttributes(void) const
{
	int attrs = 0;

	if (GetOverrideVars())
		attrs |= ModAttrCustomVariable;

	return attrs;
}

void User::SetModifiedAttributes(int flags, const MessageOrigin& origin)
{
	if ((flags & ModAttrCustomVariable) == 0) {
		SetOverrideVars(Empty);
		OnVarsChanged(this, GetVars(), origin);
	}
}

bool User::GetEnableNotifications(void) const
{
	if (!GetOverrideEnableNotifications().IsEmpty())
		return GetOverrideEnableNotifications();
	else
		return GetEnableNotificationsRaw();
}

void User::SetEnableNotifications(bool enabled, const MessageOrigin& origin)
{
	SetOverrideEnableNotifications(enabled);

	OnEnableNotificationsChanged(this, enabled, origin);
}

