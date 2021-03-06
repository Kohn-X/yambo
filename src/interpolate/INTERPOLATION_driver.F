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
subroutine INTERPOLATION_driver(bands,SEED_k,SEED_E,SEED_RT,SEED_QP,SEED_R3,&
&                               OUT_k,OUT_E,operation,QUIET,ID_op,&
&                               NEAREST,GRID)
 !
 use pars,                 ONLY:SP
 use real_time,            ONLY:RT_t
 use R_lattice,            ONLY:bz_samp,bz_samp_reset
 use electrons,            ONLY:levels,n_sp_pol
 use interpolate_tools,    ONLY:INTERPOLATION_reset,init_ID,FILL_SEED_E,FILL_SEED_RT,&
&                               INTERPOLATION_nearest_k_report,FILL_SEED_QP
 use interpolate,          ONLY:GRID_k,INTERP_obj,max_interpls,INTERPOLATION_coefficients,&
&                               INTERPOLATION_BZ,interpls,INTERPOLATION_nearest_k,&
&                               lattice_vectors,l_INTERP_f,l_INTERP_E,l_INTERP_dE,l_INTERP_W,&
&                               INTERPOLATE_initialized,l_integral_respect,l_INTERP_Z,INTERPOLATE_msg_fmt
 use IO_m,                 ONLY:IO_and_Messaging_switch
 use QP_m,                 ONLY:QP_t
 !
#include<memory.h>
 !
 integer,       intent(in),    optional :: bands(2)
 type(bz_samp), intent(in),    optional :: SEED_k
 type(bz_samp), intent(inout), optional :: OUT_k
 type(RT_t),    intent(in)   , optional :: SEED_RT
 type(levels),  intent(in)   , optional :: SEED_E
 type(QP_t),    intent(in)   , optional :: SEED_QP
 real(SP),      intent(in)   , optional :: SEED_R3(:,:,:)
 type(levels),  intent(inout), optional :: OUT_E
 character(*),  intent(in)              :: operation
 logical,       intent(in)   , optional :: QUIET,NEAREST
 integer,       intent(in)   , optional :: GRID(3)
 integer,       intent(inout), optional :: ID_op
 !
 ! Work Space
 !
 integer               :: ib,ID,i_obj,n(2),nk
 !
 ! Actions
 !=========
 !
 l_INTERP_f =operation(1:1)== "f".or.operation(1:2)== "df"
 l_INTERP_E =operation(1:1)== "E"
 l_INTERP_Z =operation(1:1)== "Z"
 l_INTERP_W =operation(1:1)== "W"
 l_INTERP_dE=operation(1:2)== "dE"
 !
 if (index(operation,"_from_DB")>0) then
   l_INTERP_dE =index(operation(1:3),"dE")>0
   l_INTERP_W  =index(operation(1:3),"W")>0
   l_INTERP_Z  =index(operation(1:3),"Z")>0
 endif
 !
 ! SETUP
 !=======
 !
 if (present(QUIET)) then
  if (QUIET) call IO_and_Messaging_switch("-log")
 endif
 !
 if (operation=="GRID") then
  !
  call bz_samp_reset(GRID_k)
  GRID_k%description="INTERP_GRID"
  call INTERPOLATION_create_the_grid(GRID_k,'i',GRID)
  !
  return
  !
 endif
 !
 if (operation=="END") then
   !
   if (present(ID_op)) then
     !
     if (ID_op==0) return 
     if (.not.INTERP_obj(ID_op)%in_use) return 
     !
     call INTERPOLATION_reset(ID_op)
     !
   else
     !
     do i_obj=1,max_interpls
       call INTERPOLATION_reset(i_obj)
     enddo
     !
     YAMBO_FREE_P(lattice_vectors)
     !
     INTERPOLATE_initialized=.FALSE.
     INTERPOLATE_msg_fmt="rs"
     !
   endif
   !
   return
   !
 endif
 !
 ! ID to use
 !===========
 !
 if (present(SEED_k)) then
   !
   do i_obj=1,max_interpls
     if (.not.INTERP_obj(i_obj)%in_use) then 
       ID=i_obj
       exit
     endif
   enddo
   !
   if (present(ID_op)) then
     ID_op=ID
   endif
   !
 else if (present(OUT_k)) then
   !
   do i_obj=1,max_interpls
     if (operation==trim(INTERP_obj(i_obj)%what)) ID=i_obj
   enddo
   !
 endif
 !
 ! SEED
 !======
 !
 if (present(SEED_k)) then
   !
   if (present(SEED_E))  INTERP_obj(ID)%D=n_sp_pol
   if (present(SEED_RT)) INTERP_obj(ID)%D=n_sp_pol
   if (present(SEED_QP)) then
     INTERP_obj(ID)%D=0
     if (l_INTERP_dE) INTERP_obj(ID)%D=INTERP_obj(ID)%D+n_sp_pol
     if (l_INTERP_W ) INTERP_obj(ID)%D=INTERP_obj(ID)%D+n_sp_pol
     if (l_INTERP_Z ) INTERP_obj(ID)%D=INTERP_obj(ID)%D+n_sp_pol*2
   endif
   if (present(SEED_R3)) INTERP_obj(ID)%D=size(SEED_R3(1,1,:))
   !
   call init_ID(ID,bands,SEED_k,operation)
   !
   if (present(NEAREST)) then
     INTERP_obj(ID)%use_NN=NEAREST 
   endif
   !
   if (.not.INTERPOLATE_initialized.and..not.INTERP_obj(ID)%use_NN) then
     !
     call INTERPOLATION_BZ_setup(SEED_k)
     !
     INTERPOLATE_initialized=.TRUE.
     !
   endif
   !
   ! I asssume here that SEED_E and SEED_RT lives on the same grid of SEED_k
   !
   if (present(SEED_E)) then
     call FILL_SEED_E(ID,SEED_E)
   endif
   !
   if (present(SEED_RT)) then
     call FILL_SEED_RT(ID,SEED_RT)
   endif
   !
   if (present(SEED_QP)) then
     call FILL_SEED_QP(ID,SEED_QP)
   endif
   !
   if (present(SEED_R3)) then
     do ib=1,bands(2)-bands(1)+1
       INTERP_obj(ID)%SEED(bands(1)+ib-1,:,:)=SEED_R3(ib,:,:)
     enddo
   endif
   !
   if (.not.INTERP_obj(ID)%use_NN) then
     !
     call INTERPOLATION_coefficients(R2D=INTERP_obj(ID)%SEED,k=SEED_k,ID=INTERP_obj(ID)%ID,ID_obj=ID)
     !
   endif
   !
   return
   !
 endif
 !
 ! INTERPOLATION...
 !==================
 !
 if (present(OUT_k)) then
   !
   ! ... Allocation
   !
   n =INTERP_obj(ID)%nb
   nk=INTERP_obj(ID)%nk
   !
   if (present(OUT_E)) then
     if (l_INTERP_E.or.l_INTERP_dE) then
       YAMBO_ALLOC(OUT_E%E,(n(1):n(2),OUT_k%nibz,INTERP_obj(ID)%D))
     else if (l_INTERP_f) then
       YAMBO_ALLOC(OUT_E%f,(n(1):n(2),OUT_k%nibz,INTERP_obj(ID)%D))
     endif
     OUT_E%nk=OUT_k%nibz
     OUT_E%nb=INTERP_obj(ID)%nb(2)
   else
     YAMBO_ALLOC(INTERP_obj(ID)%INTERP,(n(1):n(2),OUT_k%nibz,INTERP_obj(ID)%D))
   endif
   !
   ! ... Interpolation...
   !
   if (INTERP_obj(ID)%use_NN) then
     !
     ! ... Using the Nearest point method
     if (present(OUT_E)) then
       if (l_INTERP_E.or.l_INTERP_dE) then
         call INTERPOLATION_nearest_k(INTERP_obj(ID)%k,INTERP_obj(ID)%SEED,&
&                                     OUT_k%pt,        OUT_E%E)
       else if (l_INTERP_f) then
         call INTERPOLATION_nearest_k(INTERP_obj(ID)%k,INTERP_obj(ID)%SEED,&
&                                     OUT_k%pt,        OUT_E%f)
       endif
     else
       call INTERPOLATION_nearest_k(INTERP_obj(ID)%k,INTERP_obj(ID)%SEED,&
&                                   OUT_k%pt,        INTERP_obj(ID)%INTERP)
     endif
     !
     if (present(QUIET)) then
       if (.not.QUIET) call INTERPOLATION_nearest_k_report(ID)
     else
                       call INTERPOLATION_nearest_k_report(ID)
     endif
     !
   else
     !
     ! ... Using BOLTZ method
     if (present(OUT_E)) then
       if (l_INTERP_E.or.l_INTERP_dE) then
         call INTERPOLATION_BZ(K=OUT_k,R2D=OUT_E%E,ID=INTERP_obj(ID)%ID)
       else if (l_INTERP_f) then
         call INTERPOLATION_BZ(K=OUT_k,R2D=OUT_E%f,ID=INTERP_obj(ID)%ID)
       endif
     else
       call INTERPOLATION_BZ(K=OUT_k,R2D=INTERP_obj(ID)%INTERP,ID=INTERP_obj(ID)%ID)
     endif
   endif
   !
   ! f/dF normalization
   !====================
   !
   if (l_INTERP_f) then
     if (present(OUT_E)) then
       call INTERPOLATION_integral_respect(ID,OUT_k,OUT_E%f,l_integral_respect)
     else
       call INTERPOLATION_integral_respect(ID,OUT_k,INTERP_obj(ID)%INTERP,l_integral_respect)
     endif
   endif
   !
 endif
 !
 call IO_and_Messaging_switch("+log")
 !
end subroutine INTERPOLATION_driver
