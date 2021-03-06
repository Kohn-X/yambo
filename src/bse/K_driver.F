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
subroutine K_driver(Xen,Ken,Xk,q,X_static_pp,Xw,Dip)
 !
 use pars,           ONLY:IP
 use parser_m,       ONLY:parser
 use com,            ONLY:msg,warning,error
 use stderr,         ONLY:STRING_remove,intc
 use electrons,      ONLY:levels,n_sp_pol,BZ_DbGd_nbands,n_spin
 use frequency,      ONLY:w_samp,W_reset
 use X_m,            ONLY:X_t,X_duplicate,X_reset,global_gauge
 use DIPOLES,        ONLY:DIPOLE_t
 use BS_solvers,     ONLY:BSS_n_freqs,BSS_er,BSS_dr,BSS_mode,BSS_add_antiresonant,BSS_damp_reference,&
&                         BSS_uses_DbGd,BSS_q0,BSS_eval_JDOS,BSS_eels_to_eps
 use BS,             ONLY:BS_bands,BS_q,BS_n_g_exch,BS_K_coupling,BS_res_K_corr,BS_res_K_exchange,&
&                         BS_W_is_diagonal,BS_res_mode,BS_n_g_W,BS_K_is_ALDA,BS_cpl_mode,BS_cpl_K_corr,BS_cpl_K_exchange,&
&                         BSE_mode,BS_Blocks_and_Transitions_free,l_BSE_minimize_memory,BSqpts,L_kind
 use TDDFT,          ONLY:FXC_per_memstps,FXC_n_mem_freqs,FXC_is_retarded,FXC_n_g_corr
 use drivers,        ONLY:l_rpa_IP,l_alda_fxc,l_bs_fxc,l_bss,l_col_cut
 use parallel_m,     ONLY:PP_redux_wait,PAR_IND_WF_b_and_k
 use interfaces,     ONLY:PARALLEL_global_indexes,PARALLEL_WF_distribute,PARALLEL_WF_index,eval_G_minus_G
 use R_lattice,      ONLY:bz_samp,qindx_B,qindx_X
 use D_lattice,      ONLY:l_0D,l_1D,l_2D
#if defined _KERR
 use drivers,        ONLY:l_kerr,l_anomalous_Hall
#endif
#if defined _RT
 use drivers,        ONLY:l_rt_carriers_in_use
#endif
 !
#include<memory.h>
 !
 type(levels)  ::Xen,Ken
 type(bz_samp) ::Xk,q
 type(X_t)     ::X_static_pp
 type(DIPOLE_t)::Dip
 type(w_samp)  ::Xw
 !
 ! Work Space
 !
 type(X_t)         :: X_tddft,X_oscillators
 integer           :: iq,Max_G_m_G,iG_BSE,iGo_BSE
 type(w_samp)      :: W_bss 
 logical           :: l_bs_q
 !
 !
 BS_q=(/1,1/)
 !
 ! Joint DOS
 !===========
 BSS_eval_JDOS = index(BSS_mode,'d')/=0.or.index(BSS_mode,'s')/=0.or.l_rpa_IP
 !
 ! Need to convert eels to epsilon ? (part A)
 !===========================================
 ! If the Coulomb cutoff is not used (ie the system is 3D) eps/=eps^-1
 if (.not.l_col_cut)          BSS_eels_to_eps=trim(L_kind)=="full"
 ! If the Coulomb cutoff is     used and the system is 0D  eps= eps^-1=1 since vbar=0
 if (     l_col_cut.and.l_0D) BSS_eels_to_eps=.false.
 ! If the Coulomb cutoff is     used and the system is 1D or 2D it depends on the q-point (see later)
 !
 ! Copatibility with old inputs
 !==============================
 if (index(BSE_mode,'causal')/=0) BSE_mode='retarded'
 !
 l_BSE_minimize_memory=(Xk%nbz==1)
 !
 ! TDDFT setup and Resets
 !========================
 !
 call X_reset(X_tddft)
 call W_reset(W_bss)
 !
 call TDDFT_do_X_W_typs(-1,X_tddft,Xw)
 !
 if(.not.any((/trim(global_gauge)=="velocity".or.trim(global_gauge)=="length"/)) ) then
   call warning(" Not a valid gauge in input. Switching to lenght gauge")
   global_gauge="length"
 endif
 !
 !
 ! Logicals (Drivers)
 !====================
 if (l_rpa_IP.and.index(BSE_mode,'coupling')>0) BSE_mode='retarded'
 !
 BS_res_K_corr=index(BS_res_mode,'c')/=0
 BS_res_K_exchange=index(BS_res_mode,'x')/=0
 BS_cpl_K_corr=index(BS_cpl_mode,'c')/=0
 BS_cpl_K_exchange=index(BS_cpl_mode,'x')/=0
 BS_K_coupling=any((/BS_cpl_K_corr,BS_cpl_K_exchange/)) 
 BSS_add_antiresonant=index(BSE_mode,'retarded')/=0
 BS_W_is_diagonal=index(BS_res_mode,'d')/=0
 BS_K_is_ALDA=l_alda_fxc.and.n_spin==1
 if (n_spin>1.and.l_alda_fxc) call warning('TDDFT/ALDA not implemented for n_spin>1. Switched off')
#if defined _KERR
 call parser('EvalKerr',l_kerr)
 if(l_kerr) call parser('AnHall',l_anomalous_Hall)
#endif
 !
 ! Energy points
 !===============
 W_bss%n_freqs=BSS_n_freqs
 W_bss%er=BSS_er
 W_bss%dr=BSS_dr
 W_bss%damp_reference=BSS_damp_reference
 !
 ! Double Grid support
 !=====================
 BSS_uses_DbGd = (BZ_DbGd_nbands>=BS_bands(2)) .and. (index(BSS_mode,'i')/=0)
 !
 ! Frequencies 
 !=============
 W_bss%per_memstps=FXC_per_memstps
 call FREQUENCIES_setup(W_bss)
 FXC_n_mem_freqs=W_bss%n_freqs
 !
 ! W RL size setup looking at the max index of G-G' 
 ! ==================================================
 if (BS_res_K_corr.or.BS_cpl_K_corr) then
   Max_G_m_G=eval_G_minus_G(BS_n_g_W,maxval(qindx_B(:,:,2)))
   if (BS_n_g_W> Max_G_m_G ) then
     call warning (' W size reduced from '//trim(intc(BS_n_g_W))//' to '//trim(intc(Max_G_m_G))//' due to symmetry constraints')
     BS_n_g_W= Max_G_m_G
     call msg('s','[BSE-W] W size forced by symmetry to be :',BS_n_g_W)
   endif
 endif
 !
 !
 ! PARALLEL SETUP
 !================
 call X_duplicate(X_static_pp,X_oscillators) 
 X_oscillators%whoami=X_static_pp%whoami
 X_oscillators%ib(1:2)=BS_bands(1:2)
 X_oscillators%q0=BSS_q0
 !
 ! Tranferred momentum
 !======================
 !
 YAMBO_ALLOC(BSqpts,(3,BS_q(1):BS_q(2)))
 do iq=BS_q(1),BS_q(2)
   if (iq==1) BSqpts(:,iq) = BSS_q0
   if (iq/=1) BSqpts(:,iq) = q%pt(iq,:)
 enddo
 !
 do iq=BS_q(1),BS_q(2)
   !
   call section('*','Bethe Salpeter Equation @q'//trim(intc(iq)))
   !
   ! Need to convert eels to epsilon ? (part B)
   !===========================================
   ! If the Coulomb cutoff is used and the system is 1D or 2D eps and eels are different at finite q
   if (l_col_cut.and.(l_1D.or.l_2D)) then
     if(iq==1) BSS_eels_to_eps=.false.
     if(iq/=1) BSS_eels_to_eps=trim(L_kind)=="full"
   endif
   !
   ! BSS output arrays
   !===================
   call K_observables("ALLOC",W_bss)
   !
   if (BS_res_K_corr.or.BS_cpl_K_corr) then
     !
     ! W/X RL size setup looking at the max index of G-G' 
     ! =========
     !
     iGo_BSE=maxval(qindx_B(:,:,2))
     iG_BSE =BS_n_g_W
     if (.not.iq==1) then
       iGo_BSE=maxval((/4*qindx_B(:,:,2),qindx_X(iq,:,2)/))
       iG_BSE =max(BS_n_g_exch,BS_n_g_W)
     endif
     !
     Max_G_m_G=eval_G_minus_G(iG_BSE,iGo_BSE)
     !
     if (.not.iq==1) then
       if (BS_n_g_exch> Max_G_m_G ) then
         BS_n_g_exch= Max_G_m_G
         call warning (' Exch size reduced due to symmetry constraints')
         call msg('s','[BSE-exch] Exch size forced by symmetry to be :',BS_n_g_exch)
       endif
     endif
     !
     if (BS_n_g_W> Max_G_m_G ) then
       BS_n_g_W= Max_G_m_G
       call warning (' W size reduced due to symmetry constraints')
       call msg('s','[BSE-W] W size forced by symmetry to be :',BS_n_g_W)
     endif
     !
   endif
   !
   call DIPOLE_dimensions(Ken,Dip,BS_bands,BSS_q0)
   !
   ! ... EH space (no parallelization)
   call K_Transitions_setup(iq,Ken,Xk,Dip,.FALSE.)
   !
   !... Parallel distribution
   call PARALLEL_global_indexes(Ken,Xk,q,"Response_T_space",X=X_oscillators)
   !
   ! ... EH space (with parallelization) and Transition groups build-up
   call K_Transitions_setup(iq,Ken,Xk,Dip,.TRUE.)
   !
   !... Blocks build-up
   if (.not.l_rpa_IP) call K_blocks(iq)
   !
   ! 1. The IP Part
   ! ===============
   call K_IP(iq,Ken,Xk,Dip,W_bss)
   !
   ! Wave Functions distribution 
   !=============================
   call PARALLEL_WF_distribute(B_and_K_index=PAR_IND_WF_b_and_k,CLEAN_UP=.FALSE.)
   call PARALLEL_WF_index( )
   !
   ! 2. The KERNEL
   ! ================
   if (.not.l_rpa_IP) call K(iq,Ken,Xk,q,X_static_pp,Xw,W_bss)
   !
   ! 3. The SOLVER
   ! =================
   if (l_bss.and..not.l_rpa_IP) call K_solvers(iq,Ken,Xk,q,X_static_pp,W_bss)
   !
   !
   ! CLEAN (OBSs)
   call K_observables("FREE",W_bss)
   !
   ! CLEAN (Blocks)
   !
   call BS_Blocks_and_Transitions_free( )
   !
   !... Parallel distribution reset
   call PARALLEL_global_indexes(Ken,Xk,q,"Response_T_space",X=X_oscillators,RESET=.TRUE.)
   !
 enddo
 !
 YAMBO_FREE(BSqpts)
 !
end subroutine
