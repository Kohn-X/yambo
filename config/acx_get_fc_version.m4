#
# Copyright (C) 2000-2008 A. Marini and the YAMBO team
#              http://www.yambo-code.org
#
# This file is distributed under the terms of the GNU
# General Public License. You can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation;
# either version 2, or (at your option) any later version.
#
# This program is distributed in the hope that it will
# be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place - Suite 330,Boston,
# MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
#
AC_DEFUN([ACX_GET_FC_VERSION],
[
FCVERSION="unknown"
case "${FC}" in
    *pgf90*)
      ;;
    *abf90*)
      ;;
    *ifc*)
      ;;
    *g95*)
      ;;
    *ifort*)
      $FC -v >& ver_
      VER_8=`grep 8. ver_   | wc -l`
      VER_9=`grep 9. ver_   | wc -l`
      VER_10=`grep 10. ver_ | wc -l`
      if ! test "$VER_8" = "0"; then
       FCVERSION="8"
      fi
      if ! test "$VER_9" = "0"; then
       FCVERSION="9"
      fi
      if ! test "$VER_10" = "0"; then
       FCVERSION="10"
      fi
      rm -f ver_
      ;;
    *)
esac
AC_MSG_CHECKING([for $FC version])
AC_MSG_RESULT([$FCVERSION])

])