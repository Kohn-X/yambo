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
subroutine SERIAL_diagonalization(n,M,E,V_left,V_right)
 !
 !  The right eigenvector V_right(j) of M satisfies
 !                   M * V_right(j) = E(j) * V_right(j)
 !  where E(j) is its eigenvalue.
 !
 !  The left eigenvector V_left(j) of M satisfies
 !                V_left(j)**H * M = E(j) * V_left(j)**H
 !  where V_left(j)**H denotes the conjugate transpose of V_left(j).
 !
 use pars,          ONLY:SP
 use linear_algebra,ONLY:LINEAR_ALGEBRA_error,M_eigenvalues,LINEAR_ALGEBRA_WS_reset,LALGEBRA_WS
 use timing_m,      ONLY:timing
#include<memory.h>
 !
 integer           :: n
 complex(SP)       :: M(n,n),E(n),V_left(n,n),V_right(n,n)
 type(LALGEBRA_WS) :: WS
 !
 allocate(WS%v_cmplx(1))
 YAMBO_ALLOC(WS%v_real,(2*n))
 call M_eigenvalues(n,M,E,V_left,V_right,WS%v_cmplx,-1,WS%v_real,WS%i_fail)
 !
 call timing('SERIAL_diagonalization',OPR='start')
 !
 if(WS%i_fail.ne.0) call LINEAR_ALGEBRA_error('M_eigenvalues (SD)','WS%v_cmplxspace failed')
 !
 WS%dim=int(real(WS%v_cmplx(1)))
 deallocate(WS%v_cmplx)
 YAMBO_ALLOC(WS%v_cmplx,(WS%dim))
 call M_eigenvalues(n,M,E,V_left,V_right,WS%v_cmplx,WS%dim,WS%v_real,WS%i_fail)
 !
 if(WS%i_fail.ne.0) call LINEAR_ALGEBRA_error('M_eigenvalues (SD)','failed')
 !
 call LINEAR_ALGEBRA_WS_reset(WS)
 !
 call timing('SERIAL_diagonalization',OPR='stop')
 !
end subroutine
