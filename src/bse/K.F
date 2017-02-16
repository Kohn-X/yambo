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
subroutine K(iq,Ken,Xk,q,X,Xw,W_bss)
 !
 ! K = <2V-W>
 !
 use pars,         ONLY:SP,pi,IP
 use LOGO,         ONLY:pickup_a_random
 use memory_m,     ONLY:mem_est
 use drivers,      ONLY:l_bs_fxc,l_col_cut
 use frequency,    ONLY:w_samp
 use electrons,    ONLY:levels,n_sp_pol,spin_occ,spin
 use FFT_m,        ONLY:fft_size
 use stderr,       ONLY:intc
 use wave_func,    ONLY:wf_load,WF_free
 use functions,    ONLY:K_scatter
 use D_lattice,    ONLY:nsym,DL_vol,i_time_rev,sop_tab,sop_inv,i_space_inv,inv_index
 use R_lattice,    ONLY:G_m_G,g_rot,qindx_B,qindx_X,bz_samp,RIM_qpg,&
&                       RIM_anisotropy,ik_is_table,bare_qpg
 use par_proc_m,   ONLY:pp_redux_wait,myid,ncpu
 use com,          ONLY:msg,warning,error
 use timing,       ONLY:live_timing,nhash
 use X_m,          ONLY:X_alloc,X_t,X_mat
 use BS,           ONLY:BS_bands,BS_eh_E,BS_res_K_corr,BS_W_is_diagonal,&
&                       BS_res_K_exchange,O_n_c_states,&
&                       BS_n_g_W,BS_blk_dim,O_table,BS_mat,&
&                       O_phase,O_c_state,O_v_state,O_ng,BS_eh_table,BS_columns,&
&                       BS_n_g_exch,BS_identifier,BS_K_coupling,O_n_v_states,&
&                       BS_K_dim,BS_eh_win,BS_blk_coord,&
&                       cumulative_index,BS_K_is_ALDA,BS_cpl_mat,&
&                       BS_cpl_K_exchange,BSS_q0,&
&                       O_n_scatt,BS_O,BS_cpl_K_corr
 use collision,    ONLY:ggwinfo,collision_reset
 use IO_m,         ONLY:io_control,OP_RD_CL,REP,VERIFY,NONE,OP_RD,&
&                       RD,RD_CL,OP_WR_CL,OP_APP_WR_CL,RD_CL_IF_END
 use TDDFT,        ONLY:FXC_K_diagonal,FXC,FXC_n_g_corr,ioBS_Fxc
 use xc_functionals, ONLY:F_xc
 use global_XC,    ONLY:WF_kind,WF_xc_functional
 implicit none
 type(levels)  ::Ken 
 type(bz_samp) ::Xk,q
 type(X_t)     ::X
 type(w_samp)  ::Xw,W_bss
 integer       ::iq
 !
 ! Kernel loop
 !
 integer    :: ikk1,ikk2,live_timing_steps,is1xis2,ik1bz,iv1,ic1,ik1,is1,inv_s1,is1p,&
&              i_sp1,i_sp2,ik2bz,iv2,ic2,ik2,is2,is2p,&
&              icv1,icv2,iOvv,iOcc,i1,i2,i3,iqs,iq_W,ig0,bands_to_load(2)
 integer    :: iOcv, iOvc
#if defined _DOUBLE
 complex(SP):: zdotc,zdotu
#else
 complex(SP):: cdotc,cdotu
#endif
 complex(SP):: Co,H_res_x,H_res_c,H_cpl_x,H_cpl_c
 !
 ! Kernel
 !
 integer(8) :: n_K_elements(ncpu),tot_n_K_elements,i8nc,i8id
 real(SP)   :: E_eh_range(2),S_eh_range(2)
 real(SP)   :: filling
 complex(SP),allocatable ::BS_W(:,:,:)
 complex(SP),   external ::tddft_alda_r_space
 logical    :: W_is_em1s,W_is_pp
 !
 ! Oscillators
 !
 integer    :: O_dim
 integer    :: O_x_dim,alloc_err(2),x_fft_size,c_fft_size
 logical    :: load_O_X
 complex(SP),allocatable::Ovv(:),Occ(:),Cc(:),O1x(:,:),O2x(:,:)
 complex(SP),allocatable::Ovc(:),Ocv(:)
 type(ggwinfo)          ::isc
 !
 ! I/O
 !
 integer           ::ioX_err,ioBS_Fxc_err,XID,ID
 integer, external ::ioX,ioBS
 !
 Co=4._SP*pi/DL_vol/real(q%nbz,SP)
 !
 if (.not.l_bs_fxc) call section('*','Bethe-Salpeter Kernel')
 !
 !
 ! Setups
 !
 if (BS_columns<=0.or.BS_columns>Xk%nibz) BS_columns=Xk%nibz
 BS_blk_coord=0
 !
 ! Dimensions and Tables
 ! 
 allocate(BS_blk_dim(Xk%nibz))
 !
 call mem_est("BS_blk_dim",(/Xk%nbz/),(/IP/))
 if (BS_res_K_corr) then
   !
   allocate(O_n_c_states(Xk%nbz,n_sp_pol),O_n_v_states(Xk%nbz,n_sp_pol))
   call mem_est("O_n_c_states O_n_v_states",&
&               (/Xk%nbz,n_sp_pol,Xk%nbz,n_sp_pol/),(/IP,IP,IP,IP/)) !to check 
   !
 endif
 !
 call K_eh_setup(iq,Ken,Xk)
 if (any(BS_blk_dim==0)) then
   call error(' Null BSE kernel block dimension(s) found. Increase e/h range')
 endif
 !
   !
   call io_control(ACTION=OP_RD_CL,COM=REP,MODE=VERIFY,SEC=(/1/),ID=ID)
   ioBS_Fxc_err=ioBS(iq,X,ID)
   !
 !
 if (ioBS_Fxc_err==0) then
   if (BS_res_K_corr) then
     deallocate(O_v_state,O_c_state,O_n_c_states,O_n_v_states)
     call mem_est("O_v_state O_c_state O_n_c_states O_n_v_states")
   endif
   return
 endif
 !
 ! Exchange
 !
 load_O_X=BS_res_K_exchange.or.l_bs_fxc
 !
 if (.not.BS_K_coupling) then
   call             msg('rsn','[BSE] Kernel dimension    :',BS_K_dim)
 else
   call             msg('rsn','[BSE] Kernel dimension    :',2*BS_K_dim)
 endif
 if (load_O_X) call msg('r','[BSE] Exchange components :',BS_n_g_exch)
 !
 ! PP/Epsm1S DBs
 !
 W_is_em1s=X%whoami==2
 W_is_pp  =X%whoami==4
 !
 if (BS_res_K_corr&
    ) then
   call section('+','Screneed interaction header I/O')
   !
   ! X%ng are the G's in the X DB while BS_n_g_W the G's I want to read.
   ! Now to read only BS_n_g_W components I need to redefine X%ng
   !
   X%ng=BS_n_g_W
   call io_control(ACTION=OP_RD_CL,COM=REP,SEC=(/1,2/),MODE=VERIFY,ID=XID)
   ioX_err=ioX(X,Xw,XID) 
   !
   if (ioX_err/=0) call warning('BS section skipped. PP/Em1s DB does not fit/exist')
   !
   ! X%ng is set to BS_n_g_W to VERIFY if there wnough bands.
   ! From now on it is used to keep track of the actual sixe of W in the DB
   !
   X%ng=X%ng_db
   !
   if (ioX_err/=0) return
   !
 endif
 !
 ! Kernel filling
 !
 E_eh_range=(/minval(abs(BS_eh_E))-1.E-5,maxval(abs(BS_eh_E))/)
 S_eh_range=(/BS_eh_win(1)/100.*(E_eh_range(2)-E_eh_range(1)),& 
&             BS_eh_win(2)/100.*(E_eh_range(2)-E_eh_range(1))/)
 call K_filling(E_eh_range,S_eh_range,n_K_elements,tot_n_K_elements)
 !
 if (all(n_K_elements==0)) return
 !
 ! TDDFT xc-kernel Setup
 !
 if (l_bs_fxc) then
   !  
   if (iq==1) call X_O_strengths(Ken,Xk,X,BSS_q0)
   !
   ! Allocation
   !
   allocate(FXC_K_diagonal(BS_K_dim),FXC(FXC_n_g_corr,FXC_n_g_corr,W_bss%n(2)))
   call mem_est("FXC_K_diagonal FXC",(/BS_K_dim,size(FXC)/),(/SP,2*SP/))
   FXC_K_diagonal=0._SP
   FXC=(0._SP,0._SP)
 endif
 !
 ! Oscillators Setup
 !
 O_ng=maxval(G_m_G)
 !
 call fft_setup(O_ng,1,.true.)
 c_fft_size=fft_size
 call fft_setup(BS_n_g_exch,maxval(qindx_X(iq,:,2)),.true.)
 x_fft_size=fft_size
 if (x_fft_size>c_fft_size) then
   call warning('Exchange FFT size is too big. RL vectors reduced to '//intc(O_ng))
   BS_n_g_exch=O_ng
 endif
 !
 if (l_bs_fxc) then
   !
   !
 else
   !
   bands_to_load=BS_bands
   if (BS_K_is_ALDA) bands_to_load=(/1,BS_bands(2)/)
   !
   call wf_load(max(O_ng,BS_n_g_exch),1,bands_to_load,(/1,BS_columns/),&
&               space='R',title='-BSK')
   !
 endif
 ! 
 !
 allocate(O_table(BS_bands(2)-BS_bands(1)+1,nsym,&
&                 BS_bands(2)-BS_bands(1)+1,nsym,n_sp_pol),stat=alloc_err(1))
 !
 call mem_est('O_table',(/size(O_table)/),elements_kind=(/SP/),errors=(/alloc_err(1)/))
 !
 O_dim=-1
 O_x_dim=maxval(BS_blk_dim)
 do ik2=1,BS_columns
   do ik1=ik2,1,-1
     !
     if (any((/ik2<BS_blk_coord(2),ik2==BS_blk_coord(2).and.ik1>BS_blk_coord(1)/))) cycle
     !
     call K_scattering(iq,ik1,ik2,Xk,q)  
     O_dim=max(O_dim,O_n_scatt)
     !
   enddo
 enddo
 !
 !
 ! ALDA
 !
 if (BS_K_is_ALDA) then
   allocate(F_xc(fft_size))
   call xc_lda_driver(Ken,Xk,WF_KIND,WF_xc_FUNCTIONAL,2)
 endif
 !
 if (BS_res_K_corr) then
   call collision_reset(isc)
   !
   ! Screneed interaction
   !
   X%ng=BS_n_g_W
   if (W_is_em1s) call X_alloc('X',(/BS_n_g_W,BS_n_g_W,1/))
   if (W_is_pp)   call X_alloc('X',(/BS_n_g_W,BS_n_g_W,2/))
   !
   i1=BS_n_g_W
   if (BS_W_is_diagonal) i1=1
   !
   ! When TR is present but not the SI X_mat indexes need to be exchanged 
   ! when the TR is applied
   !
   if (i_space_inv==0.and.i_time_rev==1.and..not.BS_W_is_diagonal) then
     allocate(BS_W(BS_n_g_W,i1,2*q%nibz),stat=alloc_err(1))
   else
     allocate(BS_W(BS_n_g_W,i1,q%nibz),stat=alloc_err(1))
   endif
   call mem_est('BS_W',(/size(BS_W)/),errors=(/alloc_err(1)/))
   !
   allocate(isc%gamp(i1,BS_n_g_W))
   !
   call io_control(ACTION=OP_RD,COM=NONE,SEC=(/1/),ID=XID)
   ioX_err=ioX(X,Xw,XID)
   !
   do iq_W=1,q%nibz
     !
     isc%qs(2)=iq_W
     call scatterGamp(isc,'c')
     !
     call io_control(ACTION=RD_CL_IF_END,COM=NONE,SEC=(/2*iq_W,2*iq_W+1/),ID=XID)
     ioX_err=ioX(X,Xw,XID)
     !
     forall(i2=1:BS_n_g_W) X_mat(i2,i2,1)=X_mat(i2,i2,1)+1.
     do i2=1,BS_n_g_W
       do i3=1,BS_n_g_W
         if (.not.BS_W_is_diagonal) then
           BS_W(i2,i3,iq_W)=X_mat(i2,i3,1)*isc%gamp(i2,i3)
           if (i_space_inv==0.and.i_time_rev==1) &
&             BS_W(i2,i3,q%nibz+iq_W)=X_mat(i3,i2,1)*isc%gamp(i2,i3)
         endif
         if (BS_W_is_diagonal.and.i2==i3) BS_W(i2,1,iq_W)=real(X_mat(i2,i2,1))*isc%gamp(1,i2)
       enddo
     enddo
   enddo
   !
   ! Anisotropy correction. Note that isc%gamp(1,1)=RIM_anisotropy while
   ! the \delta(G,G') term must be multiplied by the standard RIM_qpg(1,1)
   !
   if (RIM_anisotropy/=0.) BS_W(1,1,1)=BS_W(1,1,1)+RIM_qpg(1,1,1)/2.-RIM_anisotropy/2.
   !
   deallocate(isc%gamp)
   call X_alloc('X')
   !
   X%ng=X%ng_db
   call collision_reset(isc)
 endif
 !
 ! DB identifier 
 !
 BS_identifier=pickup_a_random(10000.)
 !
 call section('=','Main loop')
 !
 !allocations
 !***********
 if (BS_res_K_corr.or.BS_cpl_K_corr) then
   allocate(BS_O(O_ng,O_dim),stat=alloc_err(1))
   call mem_est('BS_O',(/size(BS_O)/),errors=(/alloc_err(1)/))
   allocate(Ovv(BS_n_g_W),Occ(BS_n_g_W),Cc(BS_n_g_W))
   call mem_est('O_RES_WS',(/3*BS_n_g_W/))
   if (BS_cpl_K_corr) then
     allocate(Ovc(BS_n_g_W),Ocv(BS_n_g_W))
     call mem_est('O_CPL_WS',(/2*BS_n_g_W/))
   endif
 endif
 !
 if (load_O_X) then
   allocate(O1x(BS_n_g_exch,O_x_dim),stat=alloc_err(1))
   allocate(O2x(BS_n_g_exch,O_x_dim),stat=alloc_err(2))
   call mem_est('O1x O2x',(/size(O1x),size(O2x)/),errors=alloc_err(:2))
 endif
 !
 if (.not.BS_K_coupling) call mem_est('BS_mat',(/O_x_dim**2/))
 if (BS_K_coupling) call mem_est('BS_mat',(/2*O_x_dim**2/)) 
 !
 if (.not.l_bs_fxc) call live_timing('BSK',int(n_K_elements(myid+1),4))
 if (l_bs_fxc) call live_timing('BSK->Fxc',int(n_K_elements(myid+1),4))
 !
 tot_n_K_elements=0
 live_timing_steps=0
 i8nc=ncpu
 i8id=myid
 !
 call pp_redux_wait
 do ik2=1,BS_columns
   ikk2=sum(BS_blk_dim(:ik2-1))
   !
   if (load_O_X) call K_exchange(.not.l_col_cut,iq,ik2,Xk,O2x,O_x_dim) 
   !
   do ik1=ik2,1,-1
     !
     if (any((/ik2<BS_blk_coord(2),ik2==BS_blk_coord(2).and.ik1>BS_blk_coord(1)/))) cycle
     !
     ikk1=sum(BS_blk_dim(:ik1-1))
     !
     allocate(BS_mat(BS_blk_dim(ik1),BS_blk_dim(ik2)))
     if (BS_K_coupling) allocate(BS_cpl_mat(BS_blk_dim(ik1),BS_blk_dim(ik2)))
     !
     if (BS_res_K_corr) call K_scattering(iq,ik1,ik2,Xk,q)  
     !
     if (load_O_X) then
       !
       if (ik1/=ik2) call K_exchange(.not.l_col_cut,iq,ik1,Xk,O1x,O_x_dim)  
       if (ik1==ik2) O1x=O2x
       !
       ! When a cutoffed coulomb interaction is used bare_qpg(:,:) elements
       ! may be complex. In this case I cannot multiply both O1x and O2x by
       ! 1./bare_qpg as O2x is conjugated in the cdotc call.
       !
       if(l_col_cut) then 
         do i1=1,BS_blk_dim(ik1)
           do i2=1,BS_n_g_exch
             O1x(i2,i1)=O1x(i2,i1)/bare_qpg(iq,i2)**2
             enddo
         enddo
       endif 
       !
       O1x(1,:)=(0.,0.)
       O2x(1,:)=(0.,0.)
       !
     endif
     !
     BS_mat=(0.,0.)
     if (BS_K_coupling) BS_cpl_mat=(0.,0.)
     !
     call pp_redux_wait
     do icv1=1,BS_blk_dim(ik1)
       ik1bz=BS_eh_table(ikk1+icv1,1)
       iv1=BS_eh_table(ikk1+icv1,2)
       ic1=BS_eh_table(ikk1+icv1,3)
       i_sp1=spin(BS_eh_table(ikk1+icv1,:))
       is1=Xk%sstar(ik1bz,2)
       !
       is1p=Xk%sstar( qindx_X(iq,ik1bz,1) ,2)
       !
       do icv2=1,BS_blk_dim(ik2)
         !
         if (ik1==ik2.and.icv2<icv1) cycle
         !
         ! ::: E/h energy window :::
         !
         if (.not.K_scatter(abs(BS_eh_E(ikk1+icv1)),abs(BS_eh_E(ikk2+icv2)),&
&                           E_eh_range,S_eh_range)) cycle
         !
         ! ::: Parallel Switch :::
         !
         tot_n_K_elements=tot_n_K_elements+1
         if (mod(tot_n_K_elements-i8id,i8nc)/=1.and.ncpu>1)  cycle
         !
         ! ::: Timing START :::
         !
         live_timing_steps=live_timing_steps+1
         if (live_timing_steps==n_K_elements(myid+1)/10/nhash) then
           call live_timing(steps=live_timing_steps)
           live_timing_steps=0
         endif
         !
         ! ::: Timing END :::
         !
         ik2bz=BS_eh_table(ikk2+icv2,1)
         iv2=BS_eh_table(ikk2+icv2,2)
         ic2=BS_eh_table(ikk2+icv2,3)
         i_sp2=spin(BS_eh_table(ikk2+icv2,:))
         is2 =Xk%sstar(ik2bz,2)
         is2p=Xk%sstar( qindx_X(iq,ik2bz,1) ,2)
         ig0 =qindx_B(ik1bz,ik2bz,2)
         iq_W=q%sstar( qindx_B(ik1bz,ik2bz,1) ,1)
         iqs =q%sstar( qindx_B(ik1bz,ik2bz,1) ,2)
         !
         H_res_x=(0.,0.)
         H_res_c=(0.,0.)
         H_cpl_x=(0.,0.)
         H_cpl_c=(0.,0.)
         ! 
         ! :::Exchange    (resonant):::
         !
#if defined _DOUBLE
         if (BS_res_K_exchange) H_res_x=zdotc(BS_n_g_exch,O2x(1,icv2),1,O1x(1,icv1),1)
#else
         if (BS_res_K_exchange) H_res_x=cdotc(BS_n_g_exch,O2x(1,icv2),1,O1x(1,icv1),1)
#endif
         !
         !
         ! :::ALDA        (resonant):::
         !
         if (BS_K_is_ALDA) H_res_x=H_res_x+&
&                          tddft_alda_R_space(iq,(/ic1,ic2/),(/ik1,ik2,ik1,ik2/),&
&                                                (/iv1,iv2/),(/is1,is2,is1,is2/),1)
         !
         !
         ! :::Correlation (resonant):::
         !
         if (BS_res_K_corr.and.i_sp1==i_sp2) then
           iOcc=O_table(ic1-BS_bands(1)+1,is1, ic2-BS_bands(1)+1,is2,i_sp1)
           iOvv=O_table(iv1-BS_bands(1)+1,is1p,iv2-BS_bands(1)+1,is2p,i_sp2)
           inv_s1=sop_inv(is1)
           is1xis2=sop_tab(sop_inv(is1),is2)
           !
           forall(i1=1:BS_n_g_W) Occ(i1)=&
&                BS_O(g_rot(inv_s1,G_m_G(g_rot(iqs,i1),ig0)),iOcc)*O_phase(is1xis2,ic2,i_sp1)
           forall(i1=1:BS_n_g_W) Ovv(i1)=&
&                BS_O(g_rot(inv_s1,G_m_G(g_rot(iqs,i1),ig0)),iOvv)*O_phase(is1xis2,iv2,i_sp2)
           !
           if (is1>nsym/(i_time_rev+1)) Ovv=conjg(Ovv)
           if (is1>nsym/(i_time_rev+1)) Occ=conjg(Occ)
           if (BS_W_is_diagonal) then
             !
             forall(i1=1:BS_n_g_W) Cc(i1)=Occ(i1)*BS_W(i1,1,iq_W)
             !
           else
             !
             if (iqs>nsym/(i_time_rev+1) .and. i_space_inv == 0 ) iq_W=q%nibz+iq_W
             !
             do i1=1,BS_n_g_W 
#if defined _DOUBLE
               Cc(i1)=zdotu(BS_n_g_W,Occ,1,BS_W(1,i1,iq_W),1)
#else
               Cc(i1)=cdotu(BS_n_g_W,Occ,1,BS_W(1,i1,iq_W),1)
#endif
             enddo
           endif
           !
#if defined _DOUBLE
           H_res_c=zdotc(BS_n_g_W,Ovv,1,Cc,1)*4.*pi
#else
           H_res_c=cdotc(BS_n_g_W,Ovv,1,Cc,1)*4.*pi
#endif
           !
         endif
         !
         !
         ! Impose the kernel to be hermitian
         !
         if (ik1==ik2.and.icv1==icv2) H_res_c=real(H_res_c)
         !
         BS_mat(icv1,icv2)=H_res_x*real(spin_occ)*Co-H_res_c
         !
         !
       enddo
     enddo
     call pp_redux_wait(BS_mat)
     if (BS_K_coupling) call pp_redux_wait(BS_cpl_mat)
     !
     if (l_bs_fxc) then
       !
       !
     else
       if (ik2==1.and.ik1==1) then
         call io_control(ACTION=OP_WR_CL,COM=REP,SEC=(/1,cumulative_index(1,1)/),ID=ID)
       else
         call io_control(ACTION=OP_APP_WR_CL,COM=REP,SEC=(/cumulative_index(ik1,ik2)/),ID=ID)
       endif
       ioBS_Fxc_err=ioBS(iq,X,ID)
     endif
     !
     deallocate(BS_mat)
     if (BS_K_coupling) deallocate(BS_cpl_mat)
   enddo
 enddo
 !
 ! Live Timing finalize
 !
 live_timing_steps=mod( n_K_elements(myid+1) , int(10*nhash,KIND=KIND(n_K_elements)) )
 if (live_timing_steps>0) call live_timing(steps=live_timing_steps)
 call live_timing()
 call pp_redux_wait
 !
 ! CLEAN
 !
 deallocate(O_table)
 call mem_est("O_table")
 !
 call WF_free()
 call mem_est("BS_mat")
 !
 if (BS_res_K_corr.or.BS_cpl_K_corr) then
   deallocate(O_v_state,O_c_state,O_n_c_states,O_n_v_states)
   call mem_est("O_v_state O_c_state O_n_c_states O_n_v_states")
   deallocate(BS_W,O_phase,ik_is_table)
   call mem_est("BS_W O_phase ik_is_table")
   deallocate(Ovv,Occ,Cc)
   call mem_est("O_RES_WS")
   deallocate(BS_O)
   call mem_est("BS_O")
   !
   !
 endif
 !
 if (load_O_X) then
   deallocate(O1x,O2x)
   call mem_est("O1x O2x")
 endif
 !
 if (l_bs_fxc) then
   !
   !
 else if (BS_K_is_ALDA) then
   deallocate(F_xc)
 endif
 !
end subroutine