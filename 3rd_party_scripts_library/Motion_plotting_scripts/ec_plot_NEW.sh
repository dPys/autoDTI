#!/bin/bash
#
# Adapted from ec_plot to produce similar plots for eddy.
# Pass it exactly the same string as you used for the --out
# argument when running eddy.
#

if [ $# -ne 1 ] ; then
  echo "Usage: `basename $0` <eddy output basename>"
  exit 1;
fi

parfile=${1}.eddy_parameters
if [ ! -f $parfile ]; then
    echo "$parfile not found"
    exit 1
fi

sed 's/[\t ][\t ]*/ /g' < $parfile | cut -d' ' -f 1-3  > eddy_trans.txt
sed 's/[\t ][\t ]*/ /g' < $parfile | cut -d' ' -f 4-6  > eddy_rot.txt

echo "x" > grot_labels.txt
echo "y" >> grot_labels.txt
echo "z" >> grot_labels.txt

$FSLDIR/bin/fsl_tsplot -i eddy_rot.txt -t 'Eddy Current estimated rotations (radians)' -l grot_labels.txt -o eddy_rot.png
$FSLDIR/bin/fsl_tsplot -i eddy_trans.txt -t 'Eddy Current estimated translations (mm)' -l grot_labels.txt -o eddy_trans.png

rmsfile=${1}.eddy_movement_rms
if [ -f $rmsfile ]; then
    echo "absolute" > grot_labels.txt
    echo "relative" >> grot_labels.txt
    $FSLDIR/bin/fsl_tsplot -i $rmsfile -t 'Eddy Current estimated mean displacement (mm)' -l grot_labels.txt -o eddy_disp.png   
fi

rm -f MOTION_OUTLIERS.txt 2>/dev/null
touch MOTION_OUTLIERS.txt

##CHECK TRANSLATION THRESHOLDS
# Total volumes
tot_vols=`cat eddy_trans.txt | wc -l`

#check number of lines that x values are greater than 2 mm or less than -2 mm translated
p_trans=`awk '$3>2 || $2>2 || $1>2' eddy_trans.txt | wc -l`
n_trans=`awk '$3<-2 || $2<-2 || $1<-2' eddy_trans.txt | wc -l`

Total_translines=`expr $p_trans + $n_trans`

perc_trans=$(echo "scale=4;(($Total_translines/$tot_vols))*100" | bc | awk '{print int($1+0.5)}')

if [ $perc_trans -gt 10 ]; then
	echo -e "\e[41mPARTICIPANT UNUSABLE DUE TO MOTION. "$perc_trans"% TRANSLATION EXCEEDS RECOMMENDED THRESHOLD OF 2MM\e[0m" >> MOTION_OUTLIERS.txt
else
	echo -e "\e[42mTRANSLATION OF VOLUMES DUE TO MOTION LOOKS ACCEPTABLE. "$perc_trans"% Translation.\e[0m" >> MOTION_OUTLIERS.txt
fi

##CHECK ROTATION THRESHOLDS
# Total volumes
tot_vols=`cat eddy_rot.txt | wc -l`

#check number of lines that x values are greater than 2 mm or less than -2 mm translated
p_rot=`awk '$3>.2 || $2>.2 || $1>.2' eddy_rot.txt | wc -l`
n_rot=`awk '$3<-.2 || $2<-.2 || $1<-.2' eddy_rot.txt | wc -l`

Total_rot=`expr $p_rot + $n_rot`

perc_rot=$(echo "scale=4;(($Total_rot/$tot_vols))*100" | bc | awk '{print int($1+0.5)}')

if [ "$perc_rot" -gt 10 ];
then
	echo -e "\e[41mPARTICIPANT UNUSABLE DUE TO MOTION. "$perc_rot"% Rotation EXCEEDS RECOMMENDED THRESHOLD OF .2 Degrees\e[0m" >> MOTION_OUTLIERS.txt
else
	echo -e "\e[42mROTATION OF VOLUMES DUE TO MOTION LOOKS ACCEPTABLE. "$perc_rot"% Rotation.\e[0m" >> MOTION_OUTLIERS.txt
fi

rm -f grot_labels.txt
cat MOTION_OUTLIERS.txt
