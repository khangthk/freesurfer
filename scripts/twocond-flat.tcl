#!/usr/bin/env tclsh

##
## twocond-flat.tcl
## tksurfer script: twocond-flat [read,smooth,disp phase-encoded data 2D patch]
##
##
## Copyright © 2021 The General Hospital Corporation (Boston, MA) "MGH"
##
## Terms and conditions for use, reproduction, distribution and contribution
## are found in the 'FreeSurfer Software License Agreement' contained
## in the file 'LICENSE' found in the FreeSurfer distribution, and here:
##
## https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferSoftwareLicense
##
## Reporting: freesurfer@nmr.mgh.harvard.edu
##
#############################################################################
#############################################################################

# NOTE: to get effect of nomid scripts
#setenv flatzrot 105    ;# nomidzrot still recognized, too
#setenv flatscale 1.2
#setenv patchname patch-nomid.1000        ;# else default patch
#tksurfer -$name $hemi 1000a -tcl polar-flat.tcl

#### session dir autoset to $cwd/.. when cwd=scripts
#setsession ~/fmri/MARTY0928/10138

#### file defaults: can reset in csh script with setenv
set dir 003B/image0                 ;# usually set in calling script setenv
set floatstem sig                   ;# float file stem
#set statname f                     ;# F stats (default: statflag=0: Fourier)
set statname ""                     ;# F stats (default: statflag=0: Fourier)
set realname 2                      ;# analyse Fourier infix
set complexname 3                   ;# analyse Fourier infix
set rgbname twocond                 ;# name of rgbfiles
set patchname patch

#### parm defaults: can reset in csh script with setenv
puts "tksurfer: [file tail $script]: set flags"
set overlayflag 1       ;# overlay data on gray brain
set surfcolor 1         ;# draw the curvature under data
set avgflag 1           ;# make half convex/concave
set complexvalflag 1    ;# two-component data
set colscale 4          ;# 0=wheel,1=heat,2=BR,3=BGR,4=twocondGR,5=gray
set angle_offset 0.0    ;# phase offset
set angle_cycles 1.0    ;# adjust range
set fthresh 0.3         ;# val/curv sigmoid zero (neg=>0)
set fslope 1.5          ;# contast (was fsquash 2.5)
set fmid   1.5          ;# set linear region
set flatzrot 0
set flatscale 1.0
set smoothsteps 10
set offset 0.20         ;# default lighting offset
set statflag 0          ;# default: Fourier

#### read default patch view if there
source $env(FREESURFER_HOME)/lib/tcl/setdefpatchview.tcl

#### read non-cap setenv vars (or ext w/correct rgbname) to override defaults
source $env(FREESURFER_HOME)/lib/tcl/readenv.tcl

#### read curvature (or sulc)
puts "tksurfer: [file tail $script]: read curvature"
read_binary_curv

#### read patch (overwrites initial surface read in)
puts "tksurfer: [file tail $script]: read patch"
setfile patch ~/surf/$hemi.$patchname
read_binary_patch

#### read F-stat data
if {$statflag} {
  puts "tksurfer: [file tail $script]: read and smooth F-stats"
  setfile val */$dir/${floatstem}${statname}-$hemi.w
  read_binary_values
  smooth_val $smoothsteps
  swap_stat_val
} else {
  #### read and smooth complex component MRI Fourier transform of data
  puts "tksurfer: [file tail $script]: read and smooth complex Fourier comp"
  setfile val */$dir/${floatstem}${complexname}-$hemi.w
  read_binary_values
  smooth_val $smoothsteps
  shift_values     ;# shift complex component out of way
  #### read and smooth real component MRI Fourier transform of data
  puts "tksurfer: [file tail $script]: read and smooth real Fourier comp"
  setfile val */$dir/${floatstem}${realname}-$hemi.w
  read_binary_values
  smooth_val $smoothsteps
}

#### initial scale and position brain
puts "tksurfer: [file tail $script]: scale, position brain"
open_window
restore_zero_position   ;# undo initial centering
rotate_brain_x -90
do_lighting_model -1 -1 -1 -1 $offset  ;# -1(def); offset=curvdiffuse (def=0.15)

#### save requested rgbs (transforms done here)
puts "tksurfer: [file tail $script]: save rgb's"
source $env(FREESURFER_HOME)/lib/tcl/saveflat.tcl

#### save phasemovie
if [info exists phasemovie] {
  puts "tksurfer: [file tail $script]: save phasemovie"
  source $env(FREESURFER_HOME)/lib/tcl/phasemovie.tcl
}

if ![info exists noexit] { exit }

