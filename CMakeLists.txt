# Icinga 2
# Copyright (C) 2012-2013 Icinga Development Team (http://www.icinga.org/)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation
# Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.

cmake_minimum_required(VERSION 2.6)
project(icinga2)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

file(STRINGS icinga2.spec VERSION_LINE REGEX "^Version: ")
string(REPLACE "Version: " "" ICINGA2_VERSION ${VERSION_LINE})

set(ICINGA2_USER "icinga")
set(ICINGA2_GROUP "icinga")
set(ICINGA2_COMMAND_USER "icinga")
set(ICINGA2_COMMAND_GROUP "icingacmd")

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/COPYING" ICINGA2_LICENSE_GPL)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/COPYING.Exceptions" ICINGA2_LICENSE_ADDITIONS)
set(ICINGA2_LICENSE "${ICINGA2_LICENSE_GPL}\n\n---\n\n${ICINGA2_LICENSE_ADDITIONS}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/LICENSE.txt" ${ICINGA2_LICENSE})

set(CPACK_PACKAGE_CONTACT "Icinga Development Team")
set(CPACK_PACKAGE_VERSION ${ICINGA2_VERSION})
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_BINARY_DIR}/LICENSE.txt")
set(CPACK_WIX_UPGRADE_GUID "68C75073-7CEF-4FC9-8DA5-581758729696")
include(CPack)

include(GetGitRevisionDescription)
set(GIT_VERSION ${CPACK_PACKAGE_VERSION})
git_describe(GIT_VERSION --tags)
configure_file(icinga-version.h.cmake icinga-version.h)

if(WIN32)
  set(Boost_USE_STATIC_LIBS ON)
  add_definitions(-DBOOST_ALL_NO_LIB)
endif()

find_package(Boost 1.41.0 COMPONENTS thread system program_options regex REQUIRED)
link_directories(${Boost_LIBRARY_DIRS})
include_directories(${Boost_INCLUDE_DIRS})

find_package(OpenSSL REQUIRED)
include_directories(${OPENSSL_INCLUDE_DIR})

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/lib ${CMAKE_CURRENT_SOURCE_DIR}/components
  ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_BINARY_DIR}/lib ${CMAKE_CURRENT_BINARY_DIR}/components
)

#set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)

if(APPLE)
  set(CMAKE_INSTALL_NAME_DIR "@executable_path/../lib/icinga2")
endif(APPLE)

if("${CMAKE_C_COMPILER_ID}" MATCHES "Clang")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Qunused-arguments")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Qunused-arguments")
endif()

if(MSVC)
  add_definitions(-D_CRT_SECURE_NO_DEPRECATE -D_CRT_NONSTDC_NO_DEPRECATE -D_SCL_SECURE_NO_WARNINGS)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MP")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")
endif()

set(LIBRARY_OUTPUT_PATH ${CMAKE_BINARY_DIR}/Bin/${CMAKE_BUILD_TYPE} CACHE PATH "Library output path")
set(EXECUTABLE_OUTPUT_PATH ${CMAKE_BINARY_DIR}/Bin/${CMAKE_BUILD_TYPE} CACHE PATH "Executable output path")

include(CheckFunctionExists)
include(CheckLibraryExists)
check_function_exists(vfork HAVE_VFORK)
check_function_exists(backtrace_symbols HAVE_BACKTRACE_SYMBOLS)
check_function_exists(pipe2 HAVE_PIPE2)
check_library_exists(crypto BIO_f_zlib "" HAVE_BIOZLIB)

include(GNUInstallDirs)
configure_file(config.h.cmake ${CMAKE_CURRENT_BINARY_DIR}/config.h)

install(
  FILES README COPYING COPYING.Exceptions AUTHORS ChangeLog INSTALL NEWS
  DESTINATION ${CMAKE_INSTALL_DOCDIR}
)

include(CTest)
enable_testing()

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

add_subdirectory(third-party)
add_subdirectory(tools)
add_subdirectory(lib)
add_subdirectory(components)
add_subdirectory(icinga-app)
add_subdirectory(etc)
add_subdirectory(itl)
add_subdirectory(doc)
add_subdirectory(test)
add_subdirectory(pki)