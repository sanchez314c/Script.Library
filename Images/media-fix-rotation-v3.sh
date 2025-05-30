#!/bin/bash
#
# Developed by Fred Weinhaus 6/29/2021 .......... revised 6/28/2022
#
# ------------------------------------------------------------------------------
#
# Licensing:
#
# Copyright © Fred Weinhaus
#
# My scripts are available free of charge for non-commercial use, ONLY.
#
# For use of my scripts in commercial (for-profit) environments or
# non-free applications, please contact me (Fred Weinhaus) for
# licensing arrangements. My email address is fmw at alink dot net.
#
# If you: 1) redistribute, 2) incorporate any of these scripts into other
# free applications or 3) reprogram them in another scripting language,
# then you must contact me for permission, especially if the result might
# be used in a commercial or for-profit environment.
#
# My scripts are also subject, in a subordinate manner, to the Imageconvert
# license, which can be found at: http://www.imageconvert.org/script/license.php
#
# ------------------------------------------------------------------------------
#
####
#
# USAGE: unrotate3 [-m mode] [-f fuzzval] [-c coords] [-b bgcolor] [-d discard]
# [-k kind] [-t trimtype] [-F fuzztrim] [-r rotate] [-g graphic] [-G gcolor]
# infile outfile
# USAGE: unrotate2 [-h or -help]
#
# OPTIONS:
#
# -m     mode          mode of unrotate; clockwise (c), counterclockwise (cc),
#                      landscape (l) or portrait (p), aspect (a), smallest (s);
#                      default=smallest
# -f     fuzzval       fuzz value for floodfilling the background to separate
#                      image from background; 0<=integer<=100; default=15
# -c     coords        pixel coordinate to extract background color and seed
#                      location for flood fill; may be expressed as gravity
#                      value (NorthWest, etc)or as "x,y" value; default is
#                      NorthWest=(0,0)
# -b     bgcolor       background color to use instead of option -c;
#                      any valid IM color; default is to use option -c
# -d     discard       discard any region that has an area smaller than
#                      this size; integer>0; default=1000
# -k     kind          kind of unrotate warp; affine (a) or rigid (r);
#                      default=affine
# -t     trimtype      type of trimming to apply to the output; choices are
#                      outer, inner or none; default=none
# -F     fuzztrim      fuzz value for trimming the output image;
#                      0<=integer<=100; default=0
# -r     rotate        rotate the output image by 90, 180 or 270;
#                      default=no extra rotation
# -g     graphic       save graphic images showing floodfilled mask or vertices
#                      on the image; choices are mask, vertices or both;
#                      default=no graphic; graphic images will be named for
#                      the input with "_mask.gif" and "_vertices.png" appended
# -G     gcolor        color for the vertices in the graphic image;
#                      any valid IM color; default=red


#
###
#
# NAME: UNROTATE2
#
# PURPOSE: To unrotate a rotated image and trim the surrounding border.
#
# DESCRIPTION: UNROTATE3 attempts to automatically unrotate the image. It
# assumes that the image contains a relatively constant color background
# area around the rotated data that is not too similar in color to the color
# near the boundary of the image data and especially not near the corners.
# The user is expected to identify the background color or a coordinate
# within the background region for the algorithm to extract the background
# color. A fuzz value should be specified when the background color is not
# uniform. A mask image is then created by a fuzzy flood fill. The extreme
# X and Y (min and max location) pixels are determined from the mask in
# order to find the four corners of the image. The dimensions of the image
# are then found from the four corners and these dimensions are used for the
# output image. The two sets of four points are then used as control points
# to do either an Affine warp or a Rigid Affine warp to effectively unrotate
# the image. For mode=aspect, the aspect ratio of the input image will
# determine the orientation of the output. This may not be an accurate
# measure, if the input image is largely padded. When mode=smallest, the
# process will unrotate by the smaller of the two directions (clockwise or
# counterclockwise). This will produce the correct result only if the input
# image was rotated by less than 45 degrees. When kind=affine, a full affine
# warp will be used, which may cause some skew change. When kind=rigid, a
# rigid affine warp will be used, which is rotation and scale with no skew.
# Either may leave a bit of border, which may mitigated with the trim option.
#
#
# Arguments:
#
# -m mode ... MODE of orientation of the image. Choices are clockwise (c),
# counterclockwise(cc), landscape (l), portrait (p), aspect (a) or
# smallest (s). The default=smallest (of the two rotation directions).
#
# -f fuzzval... FUZZVAL is the fuzz value for flood filling the
# background in order to separate the image from the background. Values are
# 0<=integer<=100. The default=15.
#
# -c coords ... COORDS are the pixel coordinates to identify the background
# color and to seed the location for the flood fill. It may be expressed as
# a gravity value (NorthWest, etc) or as an "x,y" value. The default is
# NorthWest, i.e., 0,0.
#
# -b bgcolor ... BGCOLOR is the background color to use instead of option -c.
# Any valid IM color is allowed. The default is to use option -c.
#
# -d discard ... DISCARD any region that has an area smaller than this size
# when identifying the largest white area in the mask representing the image
# region. That is merge small regions into its surrounding color. Values are
# integer>0. The default=1000.
#
# -k kind ... KIND of unrotate warp. Choices are: affine (a) or rigid (r).
# The default=affine.
#
# -t trimtype ... TRIMTYPE is the type of trimming to apply to the output.
# The choices are outer (0), inner (i) or none (n). The default=outer.
#
# -F fuzztrim ... FUZZTRIM is the fuzz value for trimming the output image.
# Values are 0<=integer<=100. The default=0.
#
# -r rotate ... ROTATE specifies to rotate the output image by 90, 180 or 270.
# The default is no extra rotation.
#
# -g graphic ... GRAPHIC saves graphic images showing floodfilled mask or
# vertices on the image. The choices are: mask (m), vertices (v) or both (b).
# The default=no graphic. The graphic images will be named for the input
# with "_mask.gif" and "_vertices.png" appended.
#
# -G gcolor GCOLOR is the color for the vertices in the graphic image.
# Any valid IM color. The default=red.
#
# LIMITATIONS: This script may not perform well on nearly square images and
# may be off by increments of 90 degrees even for rectangular images. It is
# important that the fuzzy floodfill not cut off the corners of the image.
# Also, -t inner requires at least ImageMagick 7.0.8-31 or 6.9.10-31
# but seems to work best with Imagemagick 7.
#
# CAVEAT: No guarantee that this script will work on all platforms,
# nor that trapping of inconsistent parameters is complete and
# foolproof. Use At Your Own Risk.
#
######
#

# set default values
mode="smallest"				# clockwise, counterclockwise, landscape, portrait, aspect, smallest
fuzzval=15				    # fuzz value for floodfill
coords="0,0"				# coords to get background color
bgcolor=""					# background color
discard=1000				# maximum area to discard
trimtype="none"			    # none, inner or outer trim
fuzztrim=0					# fuzz value for trimming
rotate=0					# rotate image by 0, 90, 180 or 270
kind="affine"				# affine or rigid
graphic=""				    # mask or vertices image
gcolor="red"				# vertices color

# set directory for temporary files
# tmpdir="/tmp"
tmpdir="."

# Set up functions to report Usage and Usage with Description
PROGNAME="$(type "$0" | awk '{print $3}')"  # search for executable on path
PROGDIR="$(dirname "$PROGNAME")"            # extract directory of program
PROGNAME="$(basename "$PROGNAME")"          # base name of program

usage1() {
    echo >&2 ""
    echo >&2 "$PROGNAME:" "$@"
    sed >&2 -e '1,/^####/d;  /^###/g;  /^#/!q;  s/^#//;  s/^ //;  4,$p' "$PROGDIR/$PROGNAME"
}

usage2() {
    echo >&2 ""
    echo >&2 "$PROGNAME:" "$@"
    sed >&2 -e '1,/^####/d;  /^######/g;  /^#/!q;  s/^#*//;  s/^ //;  4,$p' "$PROGDIR/$PROGNAME"
}


# Function to report error messages
errMsg() {
    echo ""
    echo $1
    echo ""
    usage1
    exit 1
}

# Function to test for minus at start of value of second part of option 1 or 2
checkMinus() {
    test=$(echo "$1" | grep -c '^-.*$')   # Returns 1 if match; 0 otherwise
    [ $test -eq 1 ] && errMsg "$errorMsg"
}

# Test for correct number of arguments and get values
if [ $# -eq 0 ]; then
    # Help information
    echo ""
    usage2
    exit 0
elif [ $# -gt 26 ]; then
    errMsg "--- TOO MANY ARGUMENTS WERE PROVIDED ---"
else
    while [ $# -gt 0 ]; do
        # Get parameters
        case "$1" in
            -h|-help)    # Help information
                echo ""
                usage2
                ;;
            -m)          # Mode
                shift  # To get the next parameter
                # Test if parameter starts with minus sign
                errorMsg="--- INVALID MODE SPECIFICATION ---"
                checkMinus "$1"
                mode=$(echo "$1" | tr "[:upper:]" "[:lower:]")
                case "$mode" in
                    clockwise|c) mode="clockwise" ;;
                    counterclockwise|cc) mode="counterclockwise" ;;
                    landscape|l) mode="landscape" ;;
                    portrait|p) mode="portrait" ;;
                    aspect|a) mode="aspect" ;;
                    smallest|s) mode="smallest" ;;
                    *) errMsg "--- MODE=$mode IS AN INVALID VALUE ---"
                esac
                ;;
            # ... Rest of the code for processing options ...
        esac
        shift   # Next option
    done
    # Get infile and outfile
    infile="$1"
    outfile="$2"
fi

# Test that infile and outfile are provided
[ -z "$infile" ] && errMsg "NO INPUT FILE SPECIFIED"
[ -z "$outfile" ] && errMsg "NO OUTPUT FILE SPECIFIED"

# get infile name
inname=`convert "$infile" -format "%t" info:`

# Function to merge list of in_pts and list of out_pts into alternating format for control points
mergePoints() {
    inArr=($1)
    outArr=($2)
    num_in=${#inArr[*]}
    num_out=${#outArr[*]}
    [ $num_in -ne $num_out ] && errMsg "--- UNEQUAL IN AND OUT CONTROL POINTS ---"
    cpts=""
    for ((i=0; i<num_in; i++)); do
        in="${inArr[$i]}"
        out="${outArr[$i]}"
        cpts="$cpts $in $out"
    done
}

# Function to compute the distance between two points
computeDistance() {
    pt1="$1"
    pt2="$2"
    x1=$(echo "$pt1" | cut -d, -f1)
    y1=$(echo "$pt1" | cut -d, -f2)
    x2=$(echo "$pt2" | cut -d, -f1)
    y2=$(echo "$pt2" | cut -d, -f2)
    dist=$(convert xc: -format "%[fx:hypot(($y2-$y1),($x2-$x1))]" info:)
}

# Function to compute the absolute value of the angle of a line from pt1 to pt2
computeAbsAngle() {
    pt1="$1"
    pt2="$2"
    x1=$(echo "$pt1" | cut -d, -f1)
    y1=$(echo "$pt1" | cut -d, -f2)
    x2=$(echo "$pt2" | cut -d, -f1)
    y2=$(echo "$pt2" | cut -d, -f2)
    angle=$(convert xc: -format "%[fx:abs((180/pi)*atan2(($y2-$y1),($x2-$x1)))]" info:)
}

dir="$tmpdir/UNROTATE3.$$"

mkdir "$dir" || errMsg "--- FAILED TO CREATE TEMPORARY FILE DIRECTORY ---"
trap "rm -rf $dir; exit 0" 0
trap "rm -rf $dir; exit 1" 1 2 3 15

# read the input image into the temporary cached image and test if valid
convert -quiet -regard-warnings "$infile" -alpha off +repage $dir/tmpI.mpc ||
	errMsg  "--- FILE $infile DOES NOT EXIST OR IS NOT AN ORDINARY FILE, NOT READABLE OR HAS ZERO SIZE  ---"

  # Get ImageMagick version
  im_version=$(convert -list configure | \
      sed '/^LIB_VERSION_NUMBER */!d; s//,/;  s/,/,0/g;  s/,0*\([0-9][0-9]\)/\1/g' | head -n 1)

# Test if coordinates are provided as x,y
coords1=$(expr "$coords" : '\([0-9]*,[0-9]*\)')

# Process coordinates and background color
if [ -n "$coords1" ]; then
    x=$(echo "$coords1" | cut -d, -f1)
    y=$(echo "$coords1" | cut -d, -f2)
    # Account for pad of 1
    x=$((x + 1))
    y=$((y + 1))
    coords="$x,$y"
    bgcolor=$(convert $dir/tmpI.mpc -format "%[pixel:u.p{$coords}]" info:)
else
    case "$coords" in
        ''|nw|northwest) coords="0,0" ;;
        n|north)         coords="$midwidth,0" ;;
        ne|northeast)    coords="$widthm1,0" ;;
        e|east)          coords="$widthm1,$midheight" ;;
        se|southeast)    coords="$widthm1,$heightm1" ;;
        s|south)         coords="$midwidth,$heightm1" ;;
        sw|southwest)    coords="0,$heightm1" ;;
        w|west)          coords="0,$midheight" ;;
        *)  errMsg "--- INVALID COORDS ---" ;;
    esac
    bgcolor=$(convert $dir/tmpI.mpc -format "%[pixel:u.p{$coords}]" info:)
fi

# Pad image by 1
convert $dir/tmpI.mpc -bordercolor "$bgcolor" -border 1 $dir/tmpI.mpc

# Set up for graphic
if [ "$graphic" = "mask" ] || [ "$graphic" = "both" ]; then
    gfile="+write ${inname}_mask.png"
elif [ "$graphic" = "vertices" ]; then
    gfile="+write ${inname}_vertices.png"
else
    gfile=""
fi

# Set up floodfill
if [ "$im_version" -ge "07000000" ]; then
    matte_alpha="alpha"
else
    matte_alpha="matte"
fi

# Floodfill to threshold
# Filter small objects with CCL
# Get convex hull and draw white filled polygon
# Then get its axis aligned bounding box
bbox=$(convert $dir/tmpI.mpc \
    -write mpr:img \
    -fuzz "$fuzzval%" -fill none -draw "$matte_alpha $coords floodfill" \
    -fill white +opaque none -fill black +opaque white \
    -type bilevel \
    -define connected-components:exclude-header=true \
    -define connected-components:mean-color=true \
    -define connected-components:area-threshold=$areathresh \
    -connected-components 8 \
    +write $dir/tmpM.mpc \
    -format "%@" info:- | tr "x" "+")

# Save mask
if [ "$graphic" = "mask" ] || [ "$graphic" = "both" ]; then
    convert $dir/tmpM.mpc "${inname}_mask.gif"
fi

# Process bounding box
wd=$(echo "$bbox" | cut -d+ -f1)
ht=$(echo "$bbox" | cut -d+ -f2)
xo=$(echo "$bbox" | cut -d+ -f3)
yo=$(echo "$bbox" | cut -d+ -f4)
xl=$((xo + wd - 1))
yl=$((yo + ht - 1))

# Find the intersections of the bounding rectangle with extreme limits of the image as follows:
# Crop first and last row and column and find the first non-zero (or white) pixel on each
# Add offsets back in
lt=$(convert $dir/tmpM.mpc \
    -crop 1x${ht}+${xo}+${yo} +repage \
    -define identify:locate=maximum \
    -define identify:limit=1 \
    -verbose info: | tail -n +2 | sed 's/[;]//g' | \
    awk -v xoff="$xo" -v yoff="$yo" '{OFS = ","; split($4,a,","); print xoff,a[2]+yoff}')
tp=$(convert $dir/tmpM.mpc \
    -crop ${wd}x1+${xo}+${yo} +repage \
    -define identify:locate=maximum \
    -define identify:limit=1 \
    -verbose info: | tail -n +2 | sed 's/[;]//g' | \
    awk -v xoff="$xo" -v yoff="$yo" '{OFS = ","; split($4,a,","); print a[1]+xoff,yoff}')
rt=$(convert $dir/tmpM.mpc \
    -crop 1x${ht}+${xl}+${yo} +repage \
    -define identify:locate=maximum \
    -define identify:limit=1 \
    -verbose info: | tail -n +2 | sed 's/[;]//g' | \
    awk -v xoff="$xl" -v yoff="$yo" '{OFS = ","; split($4,a,","); print xoff,a[2]+yoff}')
bm=$(convert $dir/tmpM.mpc \
    -crop ${wd}x1+${xo}+${yl} +repage \
    -define identify:locate=maximum \
    -define identify:limit=1 \
    -verbose info: | tail -n +2 | sed 's/[;]//g' | \
    awk -v xoff="$xo" -v yoff="$yl" '{OFS = ","; split($4,a,","); print a[1]+xoff,yoff}')

# Save vertices
if [ "$graphic" = "vertices" ] || [ "$graphic" = "both" ]; then
    convert $dir/tmpI.mpc -fill "$gcolor" \
        -draw "translate $lt circle 0,0 1,0" \
        -draw "translate $tp circle 0,0 1,0" \
        -draw "translate $rt circle 0,0 1,0" \
        -draw "translate $bm circle 0,0 1,0" \
        "${inname}_vertices.png"
fi

# Compute top-left to bottom-right and bottom-left to top-right dimensions
# As average from opposite sides
computeDistance "$tp" "$rt"
dist1=$dist
computeDistance "$lt" "$bm"
dist2=$dist
dist_tl2br=$(convert xc: -format "%[fx:($dist1+$dist2)/2]" info:)

computeDistance "$lt" "$tp"
dist1=$dist
computeDistance "$bm" "$rt"
dist2=$dist
dist_bl2tr=$(convert xc: -format "%[fx:($dist1+$dist2)/2]" info:)

# Get larger and smaller distances
dist_max=$(convert xc: -format "%[fx:max($dist_tl2br, $dist_bl2tr)]" info:)
dist_min=$(convert xc: -format "%[fx:min($dist_tl2br, $dist_bl2tr)]" info:)

# Match min and max distances to tl2br or bl2tr distances
test=$(convert xc: -format "%[fx:(abs($dist_max-$dist_tl2br)<(abs($dist_min-$dist_tl2br)))?1:0]" info:)
if [ $test -eq 1 ]; then
    tl2br="max_dist"
    bl2tr="min_dist"
else
    tl2br="min_dist"
    bl2tr="max_dist"
fi

#echo "$dist_tl2br; $dist_bl2tr; $dist_max; $dist_min"

# Set up for kind of unrotate warp
if [ "$kind" = "rigid" ]; then
    kind="rigidAffine"
else
    kind="Affine"
fi

# Set up for extra rotation
if [ "$rotate" = "0" ]; then
    rotating=""
elif [ "$rotate" = "90" ]; then
    rotating="-rotate 90 +repage"
elif [ "$rotate" = "180" ]; then
    rotating="-rotate 180 +repage"
elif [ "$rotate" = "270" ]; then
    rotating="-rotate 270 +repage"
fi

# Set up for trimming
if [ "$trimtype" = "outer" ]; then
    trimming="-fuzz $fuzztrim% -trim +repage"
elif [ "$trimtype" = "inner" ]; then
    trimming="-background $bgcolor -fuzz $fuzztrim% -define trim:percent-background=0% -trim +repage"
else
    trimming="-shave 1x1"
fi

# unrotate
if [ "$mode" = "clockwise" ]; then
    in_pts="$lt $tp $rt $bm"
    wd=$dist_bl2tr
    ht=$dist_tl2br
    wdm1=$(convert xc: -format "%[fx:$wd-1]" info:)
    htm1=$(convert xc: -format "%[fx:$ht-1]" info:)
    out_pts="0,0 $wdm1,0 $wdm1,$htm1 0,$htm1"
    mergePoints "$in_pts" "$out_pts"
    control_pts=$cpts
    convert $dir/tmpI.mpc \
        -set option:distort:viewport "${wd}x${ht}+0+0" \
        -mattecolor "$bgcolor" \
        -background "$bgcolor" \
        -virtual-pixel background \
        +distort $kind "$control_pts" \
        $rotating \
        $trimming \
        "$outfile"

elif [ "$mode" = "counterclockwise" ]; then
	in_pts="$tp $rt $bm $lt"
	wd=$dist_tl2br
	ht=$dist_bl2tr
	#echo "wd=$wd; ht=$ht;"
	wdm1=`convert xc: -format "%[fx:$wd-1]" info:`
	htm1=`convert xc: -format "%[fx:$ht-1]" info:`
	out_pts="0,0 $wdm1,0 $wdm1,$htm1 0,$htm1"
	mergePoints "$in_pts" "$out_pts"
	control_pts=$cpts
	#echo "cp=$control_pts"
	convert $dir/tmpI.mpc \
		-set option:distort:viewport "${wd}x${ht}+0+0" \
		-mattecolor "$bgcolor" \
		-background "$bgcolor" \
		-virtual-pixel background \
		+distort $kind "$control_pts" \
		$rotating \
		$trimming \
		"$outfile"

elif [ "$mode" = "landscape" ]; then
	if [ "$tl2br" = "max_dist" ]; then
		in_pts="$tp $rt $bm $lt"
	else
		in_pts="$lt $tp $rt $bm"
	fi
	wd=$dist_max
	ht=$dist_min
	#echo "wd=$wd; ht=$ht;"
	wdm1=`convert xc: -format "%[fx:$wd-1]" info:`
	htm1=`convert xc: -format "%[fx:$ht-1]" info:`
	out_pts="0,0 $wdm1,0 $wdm1,$htm1 0,$htm1"
	mergePoints "$in_pts" "$out_pts"
	control_pts=$cpts
	#echo "cp=$control_pts"
	convert $dir/tmpI.mpc \
		-set option:distort:viewport "${wd}x${ht}+0+0" \
		-mattecolor "$bgcolor" \
		-background "$bgcolor" \
		-virtual-pixel background \
		+distort $kind "$control_pts" \
		$rotating \
		$trimming \
		"$outfile"

elif [ "$mode" = "portrait" ]; then
	if [ "$tl2br" = "min_dist" ]; then
		in_pts="$tp $rt $bm $lt"
	else
		in_pts="$lt $tp $rt $bm"
	fi
	wd=$dist_min
	ht=$dist_max
	#echo "wd=$wd; ht=$ht;"
	wdm1=`convert xc: -format "%[fx:$wd-1]" info:`
	htm1=`convert xc: -format "%[fx:$ht-1]" info:`
	out_pts="0,0 $wdm1,0 $wdm1,$htm1 0,$htm1"
	mergePoints "$in_pts" "$out_pts"
	control_pts=$cpts
	#echo "cp=$control_pts"
	convert $dir/tmpI.mpc \
		-set option:distort:viewport "${wd}x${ht}+0+0" \
		-mattecolor "$bgcolor" \
		-background "$bgcolor" \
		-virtual-pixel background \
		+distort $kind "$control_pts" \
		$rotating \
		$trimming \
		"$outfile"

elif [ "$mode" = "smallest" ]; then
	computeAbsAngle "$tp" "$rt"
	angle1a=$angle
	computeAbsAngle "$lt" "$bm"
	angle1b=$angle
	angle1=`convert xc: -format "%[fx:($angle1a + $angle1b)/2]" info:`
	computeAbsAngle "$tp" "$lt"
	angle2a=`convert xc: -format "%[fx:180-$angle]" info:`
	computeAbsAngle "$rt" "$bm"
	angle2b=`convert xc: -format "%[fx:180-$angle]" info:`
	angle2=`convert xc: -format "%[fx:($angle2a + $angle2b)/2]" info:`
	#echo "angle1a=$angle1a; angle1b=$angle1b; angle1=$angle1; angle2a=$angle2a; angle2b=$angle2b; angle2=$angle2;"
	test=`convert xc: -format "%[fx:($angle1<$angle2)?1:0]" info:`
	if [ $test -eq 1 ]; then
		# rotate counterclockwise
		in_pts="$tp $rt $bm $lt"
		wd=$dist_tl2br
		ht=$dist_bl2tr
	else
		# rotate clockwise
		in_pts="$lt $tp $rt $bm"
		wd=$dist_bl2tr
		ht=$dist_tl2br
	fi
	#echo "wd=$wd; ht=$ht;"
	wdm1=`convert xc: -format "%[fx:$wd-1]" info:`
	htm1=`convert xc: -format "%[fx:$ht-1]" info:`
	out_pts="0,0 $wdm1,0 $wdm1,$htm1 0,$htm1"
	mergePoints "$in_pts" "$out_pts"
	control_pts=$cpts
	#echo "cp=$control_pts"
	convert $dir/tmpI.mpc \
		-set option:distort:viewport "${wd}x${ht}+0+0" \
		-mattecolor "$bgcolor" \
		-background "$bgcolor" \
		-virtual-pixel background \
		+distort $kind "$control_pts" \
		$rotating \
		$trimming \
		"$outfile"

elif [ "$mode" = "aspect" ]; then
	test=`convert $dir/tmpI.mpc -format "%[fx:w/h<1?1:0]" info:`
	if [ $test -eq 1 ]; then
		# portrait
		if [ "$tl2br" = "min_dist" ]; then
			in_pts="$tp $rt $bm $lt"
		else
			in_pts="$lt $tp $rt $bm"
		fi
		wd=$dist_min
		ht=$dist_max
	else
		# landscape
		if [ "$tl2br" = "max_dist" ]; then
			in_pts="$tp $rt $bm $lt"
		else
			in_pts="$lt $tp $rt $bm"
		fi
		wd=$dist_max
		ht=$dist_min
	fi
	#echo "wd=$wd; ht=$ht;"
	wdm1=`convert xc: -format "%[fx:$wd-1]" info:`
	htm1=`convert xc: -format "%[fx:$ht-1]" info:`
	out_pts="0,0 $wdm1,0 $wdm1,$htm1 0,$htm1"
	mergePoints "$in_pts" "$out_pts"
	control_pts=$cpts
	#echo "cp=$control_pts"
	convert $dir/tmpI.mpc \
		-set option:distort:viewport "${wd}x${ht}+0+0" \
		-mattecolor "$bgcolor" \
		-background "$bgcolor" \
		-virtual-pixel background \
		+distort $kind "$control_pts" \
		$rotating \
		$trimming \
		"$outfile"

fi

exit 0
