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
module mod_wf2y
 ! 
 implicit none
 !
 contains
   !
   subroutine wf_splitter()
     !
     use pars,           ONLY:SP,DP
     use com,            ONLY:msg
     use wave_func,      ONLY:wf_nb_io,wf_nb_io_groups,wf_ncx
     use electrons,      ONLY:n_bands
     !
     ! Work Space
     !
     real(SP),parameter :: max_wf_block_size=400. ! MB
     real(SP),parameter :: kb = 1024.0_SP
     real(SP) :: array_sz
     !
     wf_nb_io_groups=1
     wf_nb_io=n_bands
     !
     array_sz = DP*n_bands*real(wf_ncx)/kb/kb ! wf_disk_DP
     !
     ! No memory problems: no blocks
     ! 
     if (array_sz<=max_wf_block_size) return
     !
     wf_nb_io_groups = ceiling(array_sz/max_wf_block_size)
     wf_nb_io        = ceiling(real(n_bands)/wf_nb_io_groups)
     !
     if(wf_nb_io_groups .gt. n_bands) then
       wf_nb_io_groups = n_bands 
       wf_nb_io = 1
       return
     endif
     !
     array_sz = DP*wf_nb_io*real(wf_ncx)/kb/kb
     !
     call msg('s',':: WF splitter Blocks/bands/block size(Mb):',&
&                     (/wf_nb_io_groups,wf_nb_io,int(array_sz)/))
     !
   end subroutine
   !
   integer function make_real_wf(ib,ik,wf_,nc)
     !
     use pars,      ONLY:SP
     use stderr,    ONLY:intc
     use com,       ONLY:warning
     integer     :: ib,ik,nc
     real (SP)   :: wf_(2,nc)
     !
     ! Work Space
     !
     integer     :: ic,ic_start,ic_check
     real(SP)    :: c1,c2,c_norm_sq,ph_sin(nc),ph_cos(nc),ph_cos_sq(nc)
     complex(SP) :: phase,wf_c
     ic_start=-1
     ic_check=0
     make_real_wf=1
     do ic=1,nc
       c1=wf_(1,ic)
       c2=wf_(2,ic)
       c_norm_sq=c1**2.+c2**2.
       if (c_norm_sq>1.E-5) then
         ic_check=ic_check+1
         ph_cos_sq(ic)=1./(1.+(c2/c1)**2.)
         ph_cos(ic)=c1/sqrt(c_norm_sq)
         ph_sin(ic)=c2/sqrt(c_norm_sq)
         if (ic_start<0) ic_start=ic
       else
         cycle
       endif
       if (abs(ph_cos_sq(ic)-ph_cos_sq(ic_start))>0.1) then
         call warning('No phase @ band '//trim(intc(ib))//' k-point '//trim(intc(ik)))
         make_real_wf=-1
       endif
       if (ic_check>10) exit
     enddo
     phase=cmplx(ph_cos(ic_start),-ph_sin(ic_start))
     do ic=1,nc
       wf_c=cmplx(wf_(1,ic),wf_(2,ic))
       wf_(1,ic)=real(phase*wf_c)
       wf_(2,ic)=0.
     enddo
     !
   end function
   !
end module