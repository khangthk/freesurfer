#! /usr/bin/wish

package require Tix
package require BLT

source /home/kteich/fsdev/trunk/dev/scripts/tkUtils.tcl

# WIDGET BUILDING =========================================================

proc MakeHistogram { ifwTop iwwTop args } {
    global gaHisto

    # set default arguments for all fields
    set aArgs(-title) ""

    # Set arg items and make sure we have the ones we require,
    array set aArgs $args
    foreach arg {-min -max -increment -numBars -values -clut -okCmd} {
	if {![info exists aArgs($arg)]} {
	    puts "MakeHistogram: no $arg specified"
	    return
	}
    }

    set gaHisto(title) $aArgs(-title)
    set gaHisto(min) $aArgs(-min)
    set gaHisto(max) $aArgs(-max)
    set gaHisto(increment) $aArgs(-increment)
    set gaHisto(numBars) $aArgs(-numBars)
    set gaHisto(values) $aArgs(-values)
    set gaHisto(okCmd) $aArgs(-okCmd)

    hl_SetLabelColorTable $aArgs(-clut)

    set gaHisto(label,nextID) 0
    set gaHisto(label,idList) {}

    frame $ifwTop

    set bwHisto     $ifwTop.bwHisto
    set bwCancelOK  $ifwTop.bwCancelOK
    set fwLabels    $ifwTop.fwLabels

    blt::barchart $bwHisto -width 600 -height 300

    $bwHisto legend config -hide yes
    $bwHisto config -title $gaHisto(title)
    $bwHisto axis config x -rotate 90.0 -stepsize 5
    
    bind $bwHisto <ButtonPress-1> { 
	hl_NewLabelBegin %W [%W axis invtransform x %x] }
    bind $bwHisto <B1-Motion> {
	hl_NewLabelMove %W [%W axis invtransform x %x] }
    bind $bwHisto <ButtonRelease-1> {
	hl_NewLabelFinish %W [%W axis invtransform x %x] }
    bind $bwHisto <ButtonPress-2> {
	MoveLabelBegin %W [%W axis invtransform x %x] }
    bind $bwHisto <B2-Motion> { 
	MoveLabelMove %W [%W axis invtransform x %x] }
    bind $bwHisto <ButtonRelease-2> {
	MoveLabelFinish %W [%W axis invtransform x %x] }
    bind $bwHisto <ButtonPress-3> { 
	hl_DeleteLabel %W [%W axis invtransform x %x] }

    tkuMakeCancelOKButtons $bwCancelOK $iwwTop \
	-okCmd "hl_SendFillCommand"

    frame $fwLabels
    set gaHisto(widget,label) $fwLabels

    pack $bwHisto \
	-side top \
	-fill both -expand yes

    pack $bwHisto $fwLabels \
	-side top \
	-fill x -expand yes
    pack $bwCancelOK \
	-side top

    set gaHisto(widget,histo) $bwHisto
    
    hl_DrawHistogram

    return $bwHisto
}

proc hl_SetLabelColorTable { ilValueNameColors } {
    global gaHisto
    set gaHisto(CLUT,valueList) {}
    foreach valueNameColor $ilValueNameColors {
	set value [lindex $valueNameColor 0]
	set sName [lindex $valueNameColor 1]
	set color [lindex $valueNameColor 2]
	lappend gaHisto(CLUT,valueList) $value
	set gaHisto(CLUT,$value,name) $sName
	set gaHisto(CLUT,$value,color) $color
    }
}

proc hl_DrawHistogram {} {
    global gaHisto
    
    # Copy the data to the histogram.
    set names [$gaHisto(widget,histo) element names]
    foreach name $names {
	$gaHisto(widget,histo) element delete $name
    }
    set names [$gaHisto(widget,histo) marker names]
    foreach name $names {
	$gaHisto(widget,histo) marker delete $name
    }

    set min $gaHisto(min)
    set max $gaHisto(max)
    
    set nValue 0
    for { set x $gaHisto(min) } \
	{ $x < $gaHisto(max) } \
	{ set x [expr $x + $gaHisto(increment)] } {
	    set comp [expr ($x - $min) / ($max - $min)]
	    set color "\#[hl_FloatRGBColorToHexString $comp [expr 1.0 - $comp] 1.0]"
	    $gaHisto(widget,histo) element create "Value $x" \
		-xdata $x -ydata [lindex $gaHisto(values) $nValue] \
		-foreground $color -borderwidth 0 \
		-barwidth $gaHisto(increment)
	    incr nValue
	    }
    $gaHisto(widget,histo) axis config x \
	-min $gaHisto(min) -max $gaHisto(max)

    set lLimits [$gaHisto(widget,histo) axis limits y]
    set labelHeight [expr [lindex $lLimits 1] / 10.0]

    foreach id $gaHisto(label,idList) {

	set begin $gaHisto(label,$id,begin)
	set end $gaHisto(label,$id,end)
	set color $gaHisto(label,$id,color)

	$gaHisto(widget,histo) element create box-$id  \
	    -fg $color -bg $color \
	    -xdata [list [expr $begin + (($end - $begin) / 2) ]] \
	    -ydata [list $labelHeight ] \
	    -barwidth [expr $end - $begin]

	$gaHisto(widget,histo) marker create text  \
	    -coords [list [expr $begin + (($end - $begin) / 2) ] \
			 [expr $labelHeight - ($labelHeight/2)]] \
	    -text "$id"

    }
}

proc hl_FillValueMenu { iow iID } {
    global gaHisto
    $iow.mw delete 0 end
    if { [llength $gaHisto(CLUT,valueList)] > 30 } {
	set nEntry 0
	set nSubMenu 0
	while { $nEntry < [llength $gaHisto(CLUT,valueList)] } {
	    set nTopEntry [expr $nEntry + 29]
	    if { $nTopEntry >= [llength $gaHisto(CLUT,valueList)] } {
		set nTopEntry [expr [llength $gaHisto(CLUT,valueList)] - 1]
	    }
	    menu $iow.mw.mw$nSubMenu
	    $iow.mw add cascade -menu $iow.mw.mw$nSubMenu \
		-label "$gaHisto(CLUT,$nEntry,name) -> $gaHisto(CLUT,$nTopEntry,name)"
	    incr nEntry 30
	    incr nSubMenu
	}
    }
    foreach value $gaHisto(CLUT,valueList) {
	if { [llength $gaHisto(CLUT,valueList)] > 30 } {
	    set curMenu $iow.mw.mw[expr $value / 30]
	} else {
	    set curMenu $iow.mw
	}
	$curMenu add command \
	    -command "hl_ValueManuCallback $iID $value" \
	    -label $gaHisto(CLUT,$value,name)
    }
}

# UTILTIES ============================================================

# Increments a digit in hex format. Used to figure out hex colors.
proc hl_IncrHex { h } {

    if { $h < 9 } { 
	return [expr $h + 1] 
    } else {
	switch $h {
	    9 { return A }
	    A { return B }
	    B { return C }
	    C { return D }
	    D { return E }
	    E { return F }
	    F { return 0 }
	    default { return 0 }
	}
    }
}

# Builds a global hex color table for mapping colors from 0-255 to 00-FF.
proc hl_BuildHexColorTable {} {
    global gasHexColor

    set h1 0
    set h2 0
    for { set n 0 } { $n < 256 } { incr n } {
	set gasHexColor($n) "$h1$h2"
	set h2 [hl_IncrHex $h2]
	if { $h2 == 0 } {
	    set h1 [hl_IncrHex $h1]
	}
    }
}
hl_BuildHexColorTable

# Translates an RGB color with components from 0-1 to a hex color
# string from 000000 to FFFFFF.
proc hl_FloatRGBColorToHexString { iRed iGreen iBlue } {
    global gasHexColor

    set nRedColor   [expr round($iRed * 255.0)]
    set nGreenColor [expr round($iGreen * 255.0)]
    set nBlueColor  [expr round($iBlue * 255.0)]

    return $gasHexColor($nRedColor)$gasHexColor($nGreenColor)$gasHexColor($nBlueColor)
}

proc hl_IntRGBColorToHexString { iRed iGreen iBlue } {
    global gasHexColor
    return $gasHexColor($iRed)$gasHexColor($iGreen)$gasHexColor($iBlue)
}



# UI CALLBACKS =======================================================

proc hl_NewLabelBegin { ibwHisto iX } {
    global gaHisto
    set id $gaHisto(label,nextID)
    incr gaHisto(label,nextID)
    set gaHisto(label,currentID) $id
    set gaHisto(label,$id,value) [lindex $gaHisto(CLUT,valueList) 0]
    set gaHisto(label,$id,color) $gaHisto(CLUT,$gaHisto(label,$id,value),color)
    set gaHisto(event,anchor) $iX
    set gaHisto(label,$id,begin) $iX
    set gaHisto(label,$id,end) $iX
    lappend gaHisto(label,idList) $id
}

proc hl_NewLabelMove { ibwHisto iX } {
    global gaHisto
    set id $gaHisto(label,currentID)
    if { $id != -1 } {
	if { $iX < $gaHisto(event,anchor) } {
	    set gaHisto(label,$id,begin) $iX
	} else {
	    set gaHisto(label,$id,end) $iX
	}
	hl_DrawHistogram
    }
}

proc hl_NewLabelFinish { ibwHisto iX } {
    global gaHisto
    set currentID $gaHisto(label,currentID)
    set gaHisto(label,currentID) -1
    hl_ResolveLabelCollisions $currentID
    hl_DrawHistogram

    hl_NewLabelRow $currentID
}

proc MoveLabelBegin { ibwHisto iX } {
    global gaHisto
    foreach id $gaHisto(label,idList) {
	if { $iX > $gaHisto(label,$id,begin) &&
	     $iX < $gaHisto(label,$id,end) } {
	    set gaHisto(label,currentID) $id
	    set gaHisto(event,anchor) $iX
	    set gaHisto(event,origBegin) $gaHisto(label,$id,begin)
	    set gaHisto(event,origEnd) $gaHisto(label,$id,end)
	}
    }
}

proc MoveLabelMove { ibwHisto iX } {
    global gaHisto
    set id $gaHisto(label,currentID)
    if { $id != -1 } {
	set delta [expr $iX - $gaHisto(event,anchor)]
	set gaHisto(label,$id,begin) [expr $gaHisto(event,origBegin) + $delta]
	set gaHisto(label,$id,end) [expr $gaHisto(event,origEnd) + $delta]
	hl_DrawHistogram
    }
}

proc MoveLabelFinish { ibwHisto iX } {
    global gaHisto
    set id $gaHisto(label,currentID)
    if { $id != -1 } {
	set gaHisto(label,currentID) -1
	hl_ResolveLabelCollisions $id
	hl_DrawHistogram
    }
}

proc hl_DeleteLabel { ibwHisto iX } {
    global gaHisto
    foreach id $gaHisto(label,idList) {
	if { $iX > $gaHisto(label,$id,begin) &&
	     $iX < $gaHisto(label,$id,end) } {
	    set n [lsearch $gaHisto(label,idList) $id]
	    if { $n == -1 } {
		puts "Error in hl_DeleteLabel, $id not found in $gaHisto(label,idList)"
	    }
	    set gaHisto(label,idList) [lreplace $gaHisto(label,idList) $n $n]
	    hl_DrawHistogram
	    hl_DeleteLabelRow $id
	}
    }
}

proc hl_NewLabelRow { iID } {
    global gaHisto
    
    set fw [frame $gaHisto(widget,label).fw-$iID \
		-highlightthickness 2 \
		-highlightbackground $gaHisto(label,$iID,color)]

    tkuMakeActiveLabel $fw.lwBegin \
	-variable gaHisto(label,$iID,begin) \
	-label "$iID: "
    tkuMakeActiveLabel $fw.lwEnd \
	-variable gaHisto(label,$iID,end) \
	-label " - "
    
    menubutton $fw.owValue \
	-text $gaHisto(CLUT,0,name) \
	-menu $fw.owValue.mw \
	-indicatoron 1
    menu $fw.owValue.mw
    set gaHisto(widget,valueMenu,$iID) $fw.owValue

    hl_FillValueMenu $fw.owValue $iID

    pack $fw.lwBegin $fw.lwEnd \
	-side left
    pack $fw.owValue \
	-side right
    
    pack $fw -expand true -fill x
}

proc hl_ValueManuCallback { iID iValue } {
    global gaHisto
    set gaHisto(label,$iID,value) $iValue
    set gaHisto(label,$iID,color) $gaHisto(CLUT,$iValue,color)
    $gaHisto(widget,label).fw-$iID configure \
	-highlightthickness 2 \
	-highlightbackground $gaHisto(label,$iID,color)
    hl_DrawHistogram
    $gaHisto(widget,valueMenu,$iID) config -text $gaHisto(CLUT,$iValue,name)
}

proc hl_DeleteLabelRow { iID } {
    global gaHisto
    pack forget $gaHisto(widget,label).fw-$iID
}

proc hl_SendFillCommand { } {
    global gaHisto
    set lValueRanges {}
    foreach id $gaHisto(label,idList) {
	lappend lValueRanges [list $gaHisto(label,$id,begin) $gaHisto(label,$id,end) $gaHisto(label,$id,value)]
    }

    eval $gaHisto(okCmd) [list $lValueRanges]
}

# DATA ==================================================================

proc hl_ResolveLabelCollisions { iID } {
    global gaHisto

    set begin $gaHisto(label,$iID,begin)
    set end $gaHisto(label,$iID,end)
    foreach testID $gaHisto(label,idList) {

	if { $testID == $iID } { continue }
	
	set testBegin $gaHisto(label,$testID,begin)
	set testEnd $gaHisto(label,$testID,end)
	
	# Fix label collisions. .. is label, || is testLabel.
	# . | | .  ->  .    .
	if {$testBegin > $begin && $testBegin < $end &&
	    $testEnd > $begin && $testEnd < $end} {
	    # delete label
	    set n [lsearch $gaHisto(label,idList) $testID]
	    if { $n == -1 } {
		puts "Error in hl_ResolveLabelCollisions, $id not found in $gaHisto(label,idList)"
		continue
	    }
	    set gaHisto(label,idList) [lreplace $gaHisto(label,idList) $n $n]
	    hl_DeleteLabelRow $testID
	    continue
	}	
	# . | . |  ->  . .| |
	if {$testBegin > $begin && $testBegin < $end} {
	    set gaHisto(label,$testID,begin) $end
	}
	# | . | .  ->  | |. .
	if {$testEnd > $begin && $testEnd < $end} {
	    set gaHisto(label,$testID,end) $begin
	}
	# | . . |  ->  | |. .
	if {$begin > $testBegin && $begin < $testEnd &&
	    $end > $testBegin && $end < $testEnd} {
	    set gaHisto(label,$testID,end) $begin
	}

	if {$gaHisto(label,$testID,begin) > $gaHisto(label,$testID,end)} {
	    set testBegin $gaHisto(label,$testID,begin)
	    set testEnd $gaHisto(label,$testID,end)
	    set gaHisto(label,$testID,begin) $testEnd
	    set gaHisto(label,$testID,end) $testBegin
	}
    }
}
