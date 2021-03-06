!
!        Copyright (C) 2000-2019 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine QP_state_extract_print(qp)
 !
 ! Print the contents of the QP_state logical array
 !
 use pars,      ONLY:lchlen,schlen
 use QP_m,      ONLY:QP_state,QP_t
 use com,       ONLY:msg
 use stderr,    ONLY:intc
 !
 implicit none
 !
 type(QP_t), optional :: qp    
 !
 ! Work Space
 !
 integer, external :: QP_state_extract
 integer           :: i4(4)
 character(lchlen) :: ch
 !
 if (.not.present(qp)) call msg('r','')
 !
 if (present(qp)) then
   qp%n_descs=qp%n_descs+1
   qp%description(qp%n_descs)=""
 endif
 !
 i4=(/1,1,0,0/)
 do while(QP_state_extract(i4)>0)
   !
   ch='QP @ K '//trim(intc(i4(1)))//' - '//trim(intc(i4(2)))//' : b '//trim(intc(i4(3)))//' - '//trim(intc(i4(4)))
   !
   if (present(qp)) then
     qp%n_descs=qp%n_descs+1
     qp%description(qp%n_descs)=" "//trim(ch)
   else
     call msg('r',trim(ch))
   endif
   !
 enddo  
 !
 if (.not.present(qp)) call msg('r','')
 !
end subroutine
