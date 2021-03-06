!
!        Copyright (C) 2000-2019 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AF, IM
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
subroutine PP_scatterBamp_init(isc)
 !
 ! init USPP workspace in isc scatterBamp argument
 !
 use pars,          ONLY:SP,DP,pi
 use qe_pseudo_m,   ONLY:lmaxq,g,nhm,nh,upf,nat,nsp,nspin,tpiba,omega,tau
 use collision_el,  ONLY:elemental_collision
 use R_lattice,     ONLY:k_pt,q_pt,b,rl_sop
 use D_lattice,     ONLY:nsym,i_time_rev,dl_sop
 use vec_operate,   ONLY:c2a
 use timing_m,      ONLY:timing
 !
#include<memory.h>
 !
 ! vars
 !
 type(elemental_collision) :: isc

 !
 ! Workspace
 !
 integer :: ngm,ig,nt,na,ih,jh
 integer :: iGo,iq,isym
 real(SP):: q(3),q_rot(3),arg
 real(DP), allocatable :: q_plus_g(:,:)
 real(DP), allocatable :: q_plus_g_m(:)

 if (isc%ngrho<=0) return
 call timing("PP_scatterBamp_init","start")
 !
 ngm=isc%ngrho
 !
 if (.not.allocated(isc%qmod)) then
   YAMBO_ALLOC( isc%qmod,(ngm))
 endif
 if (.not.allocated(isc%qgm)) then
   YAMBO_ALLOC( isc%qgm,(ngm,nhm,nhm,nsp))
 endif
 if (.not.allocated(isc%ylmk0)) then
   YAMBO_ALLOC( isc%ylmk0,(ngm, lmaxq*lmaxq) )
 endif
 if (.not.allocated(isc%becprod)) then
   YAMBO_ALLOC( isc%becprod,(nhm,nhm,nat,nspin) )
 endif
 if (.not.allocated(isc%eiqtau)) then
   YAMBO_ALLOC( isc%eiqtau,(nat) )
 endif
 !
 YAMBO_ALLOC(q_plus_g,(3,ngm))
 YAMBO_ALLOC(q_plus_g_m,(ngm))
 !
 iGo=isc%qs(1)
 iq=isc%qs(2)
 isym=isc%qs(3)
 !
 ! q,g in cartesian, tpiba units
 !
 q_rot=matmul(rl_sop(:,:,isym),q_pt(iq,:))
 call c2a(b,q_rot,mode='ki2c')
 q=q_rot/tpiba
 !
 do ig = 1, ngm
   q_plus_g(:,ig) = real(q(:),DP) +g(:,ig)
   q_plus_g_m(ig) = sum(q_plus_g(:,ig)**2)
 enddo
 !
 call ylmr2(lmaxq*lmaxq, ngm, q_plus_g, q_plus_g_m, isc%ylmk0)
 !
 do ig = 1, ngm
    isc%qmod(ig) = sqrt(q_plus_g_m(ig))
 enddO
 !
 do na = 1, nat
   arg=2.0_SP*pi*dot_product(q,real(tau(:,na),SP))
   isc%eiqtau(na)=cmplx(cos(arg),sin(arg),SP)
 enddo
 !
 YAMBO_FREE(q_plus_g)
 YAMBO_FREE(q_plus_g_m)
 !
 ! precompute Q_ij(q+G)
 !
 do nt = 1, nsp
   !
   isc%qgm(:,:,:,nt)=0.0
   if ( .not.upf(nt)%tvanp ) cycle
   !
   do jh = 1, nh(nt)
   do ih = 1, jh
      !
      call qvan2(ngm, ih, jh, nt, isc%qmod, isc%qgm(:,ih,jh,nt), isc%ylmk0)
      !
   enddo
   enddo
   !
   isc%qgm(:,:,:,nt)=isc%qgm(:,:,:,nt)*omega
   !
 enddo
 !
 call timing("PP_scatterBamp_init","stop")
 return
 !
end subroutine PP_scatterBamp_init

