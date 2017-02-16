!
! Copyright (C) 2000-2008 A. Marini and the YAMBO team 
!              http://www.yambo-code.org
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
subroutine K_driver(Xen,Ken,Xk,q,X_static_pp,Xw)
 !
 use pars,           ONLY:SP,IP
 use parser_m,       ONLY:parser
 use com,            ONLY:msg
 use memory_m,       ONLY:mem_est
 use stderr,         ONLY:string_remove
 use electrons,      ONLY:levels,n_sp_pol
 use frequency,      ONLY:w_samp,W_reset
 use X_m,            ONLY:X_t,X_duplicate,X_reset
 use BS,             ONLY:BS_bands,BS_q,BS_blk_dim,BS_eh_table,BS_eh_E,BS_eh_f,&
&                         BS_n_g_exch,BSS_n_freqs,BSS_er,BSS_dr,&
&                         BS_K_coupling,BS_res_K_corr,BS_res_K_exchange,&
&                         BS_W_is_diagonal,BS_res_mode,BSS_mode,BS_n_g_W,&
&                         BS_K_is_ALDA,BS_cpl_mode,BS_cpl_K_corr,BS_cpl_K_exchange,&
&                         BSS_damp_reference,BS_eh_Z,BS_eh_W
 use TDDFT,          ONLY:FXC,FXC_per_memstps,FXC_n_mem_freqs,&
&                         FXC_is_causal
 use QP_CTL_m,       ONLY:QP_apply
 use drivers,        ONLY:l_bss,l_bs_fxc,l_alda_fxc
 use par_proc_m,     ONLY:pp_redux_wait
 use R_lattice,      ONLY:bz_samp,qindx_B
 use parser_m,       ONLY:parser
 implicit none
 type(levels)  ::Xen,Ken
 type(bz_samp) ::Xk,q
 type(X_t)     ::X_static_pp
 type(w_samp)  ::Xw,W_bss 
 !
 ! Work Space
 !
 integer     :: iq,bands_to_correct(2)
 type(X_t)   :: X_tddft
 integer, external :: eval_G_minus_G
 !
 call X_reset(X_tddft)
 call W_reset(W_bss)
 !
 ! In these two lines I ensure the at least all the metallic
 ! bands are included in the X summation
 !
 if (BS_bands(1)>Ken%nbf+1) BS_bands(1)=Ken%nbf+1
 if (BS_bands(2)<Ken%nbm)   BS_bands(2)=Ken%nbm
 !
 ! If using ALDA enough bands must be loaded to
 ! be able to calculate the density
 !
 bands_to_correct=BS_bands
 if (l_alda_fxc) bands_to_correct=(/1,BS_bands(2)/)
 !
 ! ... and the QP corrections
 !
 call QP_apply(bands_to_correct,Ken,Xk,2,msg_fmt='s')
 !
 !
 ! W RL size setup looking at the max index of G-G' 
 !
 if (BS_n_g_W/= eval_G_minus_G(BS_n_g_W,maxval(qindx_B(:,:,2))) ) then
   call msg('s','[BSE-W] W size forced by symmetry to be :',BS_n_g_W)
 endif
 !
 if (l_bs_fxc.or.index(BSS_mode,'t')/=0) then
   !  
   !
 else if (l_alda_fxc) then
   !  
   ! Remove the correlation from the BS_mode
   !
   BS_res_mode=trim( string_remove(BS_res_mode,'c') )
   BS_cpl_mode=trim( string_remove(BS_cpl_mode,'c') )
   !
 endif
 !
 ! Logicals (Drivers)
 !
 BS_res_K_corr=index(BS_res_mode,'c')/=0
 BS_res_K_exchange=index(BS_res_mode,'x')/=0
 BS_cpl_K_corr=index(BS_cpl_mode,'c')/=0
 BS_cpl_K_exchange=index(BS_cpl_mode,'x')/=0
 BS_K_coupling=any((/BS_cpl_K_corr,BS_cpl_K_exchange/)) 
 BS_W_is_diagonal=index(BS_res_mode,'d')/=0
 !
 !
 BS_K_is_ALDA=l_alda_fxc
 !
 ! Energy points
 !
 W_bss%n=BSS_n_freqs
 W_bss%er=BSS_er
 W_bss%dr=BSS_dr
 W_bss%damp_reference=BSS_damp_reference
 !
 ! Note that %n(2) is not used in standard BSE solvers.
 ! Only when we are using the BS derived FXC FXC_per_memstps
 ! defines %n(2) and the memory allocation of the kernel
 !
 W_bss%per_memstps=FXC_per_memstps
 call freqs_setup(W_bss)
 FXC_n_mem_freqs=W_bss%n(2)
 !
 ! KERNEL
 !
 iq=BS_q(1)
 !
 call K(iq,Ken,Xk,q,X_static_pp,Xw,W_bss)
 !
 ! SOLVER
 !
 if (l_bss) call K_solvers(iq,Ken,Xk,q,X_static_pp,W_bss)
 !
 !
 ! CLEAN
 !
 deallocate(BS_blk_dim,BS_eh_table,BS_eh_E,BS_eh_f)
 if (allocated(BS_eh_W)) deallocate(BS_eh_W)
 if (allocated(BS_eh_Z)) deallocate(BS_eh_Z)
 call mem_est("BS_blk_dim BS_eh_table BS_eh_E BS_eh_f BS_eh_W BS_eh_Z")
 !
end subroutine