#!/usr/bin/env tclsh

##
## fs-views.tcl
## surfer script: fs-views    [read fieldsign, display on folded/unfolded]
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
##############################################################################
##############################################################################

#### session dir autoset to $cwd/.. when cwd=scripts
#setsession ~/fmri/DALE0308/08798

#### file defaults: can reset in csh script with setenv
set rgbname fs

#### parm defaults: can reset in csh script with setenv
puts "tksurfer: [file tail $script]: set flags"
set overlayflag 1       ;# overlay data on gray brain
set surfcolor 1         ;# draw the curvature under data
set avgflag 1           ;# make half convex/concave
set complexvalflag 0    ;# one-component data
set autoscaleflag 1     ;# for fs,CMF
set colscale 9          ;# 0=wheel,1=heat,2=BR,3=BGR,4=twocondGR,5=gray
set angle_offset 0.0    ;# phase offset
set angle_cycles 1.0    ;# adjust range
set fthresh 0.3         ;# val/curv sigmoid zero (neg=>0)
set fslope 5.0          ;# contast
set fmid   0.6          ;# set linear region
set offset 0.20    ;# default lighting offset

#### read non-cap setenv vars (or ext w/correct rgbname) to override defaults
source $env(FREESURFER_HOME)/lib/tcl/readenv.tcl

#### read curvature (or sulc)
puts "tksurfer: [file tail $script]: read curvature"
read_binary_curv

#### deal gracefully with old style fs,fm location
if [file exists $fs] {
  # OK: fs file exists, assume fm there too
} else {
  puts "tksurfer: [file tail $script]: newstyle fs file not found"
  puts "tksurfer:     $fs"
  puts "tksurfer: [file tail $script]: looking in subjects surf dir"
  setfile fs ~/surf/[file tail $fs]
  setfile fm ~/surf/[file tail $fm]
}

#### read fieldsign color and mask
puts "tksurfer: [file tail $script]: read fieldsign"
read_fieldsign          ;# written with fs-flat.tcl
puts "tksurfer: [file tail $script]: read fieldsign mask"
read_fsmask             ;# ditto

#### override flag reset from bad setenv colscale
if {$fieldsignflag} { set complexvalflag 0 }

#### scale and position brain
puts "tksurfer: [file tail $script]: scale, position brain"
open_window
make_lateral_view       ;# rotate either hemisphere
do_lighting_model -1 -1 -1 -1 $offset ;# -1 => nochange; diffuse curv (def=0.15)

#### save requested rgbs
puts "tksurfer: [file tail $script]: save rgb's"
source $env(FREESURFER_HOME)/lib/tcl/saveviews.tcl

if ![info exists noexit] { exit }

