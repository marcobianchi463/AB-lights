#!/bin/bash

read -p "Where do you want to save output files? [./]	" OUTDIR
OUTDIR=${OUTDIR:-.}

if [-d $OUTDIR]; then
	echo "Directory exists."
else
	mkdir $OUTDIR
	echo "Directory does not exist. Created it."
fi

echo -e "Processing line intersections in \e[1;33m$1\e[0m..."
qgis_process run native:lineintersections INPUT=$1 INTERSECT=$1 OUTPUT=$OUTDIR/junctions.shp
echo "Found junctions!"
echo ""
echo "Splitting lines..."
qgis_process run native:splitwithlines INPUT=$OUTDIR/junctions.shp LINES=$1 OUTPUT=$OUTDIR/split-lines.shp
echo -e "Saved files in \e[1;33m$OUTDIR/\e[0m"
echo -e "\e[1;32mDone!\e[0m"
