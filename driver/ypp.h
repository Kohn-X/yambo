/*
         Copyright (C) 2000-2019 the YAMBO team
               http://www.yambo-code.org
 
  Authors (see AUTHORS file for details): AM
  
  This file is distributed under the terms of the GNU 
  General Public License. You can redistribute it and/or 
  modify it under the terms of the GNU General Public 
  License as published by the Free Software Foundation; 
  either version 2, or (at your option) any later version.
 
  This program is distributed in the hope that it will 
  be useful, but WITHOUT ANY WARRANTY; without even the 
  implied warranty of MERCHANTABILITY or FITNESS FOR A 
  PARTICULAR PURPOSE.  See the GNU General Public License 
  for more details.
 
  You should have received a copy of the GNU General Public 
  License along with this program; if not, write to the Free 
  Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
  MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
*/
/*
  declaration
*/
/*
 "e" and "s" commmand line structure
*/
#if defined _FORTRAN_US
 int ypp_i
#else
 int ypp_i_
#endif
(int *, int *,int *,int *,int *,int *,int *,int *,
  char *rnstr2, char *inf, char *id, char *od, char *com_dir, char *js,
  int lni,int iif,int iid,int iod,int icd,int ijs);
/*
 Command line structure
*/
 static Ldes opts[] = { /* Int Real Ch (dummy) Parallel_option*/
#include "common_options.h"
  {"bzgrids","k","BZ Grid generator [(k)pt,(q)pt,(s)hifted,(h)igh symmetry,(r)andom]",0,0,1,0,0}, 
  {"QPDBs",  "q","(g)enerate-modify/(m)erge quasi-particle databases",0,0,1,0,0}, 
  {"wannier","i","Wannier 90 interface",0,0,0,0,0}, 
  {"bxsf",   "b","Read BXSF output generated by Wannier90",0,0,0,0,0},
  {"electrons","s","Electrons [(w)ave,(d)ensity,(m)ag,do(s),(b)ands]",0,0,1,0,0}, 
#if defined _YPP_ELPH
  {"excitons", "e","Excitons  [(s)ort,(sp)in,(a)mplitude,(w)ave,(e)lias,(g)kkp]",0,0,1,0,0}, 
#else
  {"excitons", "e","Excitons  [(s)ort,(sp)in,(a)mplitude,(w)ave;qindx]",0,0,2,0,0}, 
#endif
  {"freehole","f","Free hole position [excitons plot]",0,0,0,0,0}, 
  {"kpts_map","m","BZ map fine grid to coarse",0,0,0,0,0}, 
  {"WFs",     "w","WFs:(p)erturbative SOC mapping or (c)onversion to new I/O format",0,0,1,0,0},
  {"fixsyms", "y","Remove symmetries not consistent with an external perturbation",0,0,0,0,0},
#if defined _YPP_RT
  {"RealTime","t","TD-polarization [(X)response]",0,0,1,0,0}, 
#endif
#if defined _YPP_NL
  {"nonlinear","u","Non-linear response analysis",0,0,0,0,0}, 
#endif
#if defined _YPP_ELPH
  {"phonons","p","Phonon [(d)os,(e)lias,(a)mplitude]",0,0,1,0,0}, 
  {"gkkp"  , "g","gkkp databases",0,0,0,0,0}, 
#endif
  {NULL,NULL,NULL,0,0,0,0,0}
 };
 char *tool="ypp";
 char *tdesc="Y(ambo) P(ost) P(rocessor)";
