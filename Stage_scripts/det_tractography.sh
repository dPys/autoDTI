#!/bin/bash
#    autoDTI: A dMRI pipeline for efficient and comprehensive DTI analysis
#    Copyright (C) 2016  AUTHOR: Derek Pisner
#    Contributors: Adam Bernstein, Aleksandra Klimova, Matthew Allbright
#
#    autoDTI is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published
#    by the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    autoDTI is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the complete GNU Affero General Public
#    License with autoDTI in a file called LICENSE.txt. If not, and/or you simply have
#    questions about licensing and copyright/patent restrictions with autoDTI, please
#    contact the primary author, Derek Pisner, at dpisner@utexas.edu

##Variable inputs
output_dir=${1}
PARTIC=${2}
sequence=${3}
Study=${4}
NumCores=${5}
parallel_type=${6}
NumCoresMP=${7}
det_type=${8}
debug=${9}

##Exit if run without FEED_autoDTI.sh
if [ $# -eq 0 ]; then
    echo -e "\n\n\nYou must run autoDTI by feeding command-line inputs to FEED_autoDTI.sh. Type: FEED_autoDTI.sh -h for command-line options. See README.txt for more instructions.\n\n\n"
    exit 1
fi

##Check if debug mode activated
if [[ $debug == 1 ]]; then
    set -x
fi

##Log to runlog_PARTIC
exec &> >(tee -i "$output_dir"/"$PARTIC"/logs/runlog_"$PARTIC".txt)
exec 2>&1

rm -f "$output_dir"/"$PARTIC"/det_tractography_failed.txt

if [[ $det_type != "DTI" ]] && [[ $det_type != "ODF" ]]; then
    echo -e "\nERROR: You must follow the -dt flag with either "DTI" or "ODF" when running FEED_autoDTI.sh in order for deterministic tractography to run\n\n\n"
    touch "$output_dir"/"$PARTIC"/det_tractography_failed.txt
    exit 1
fi

##Set DTK PATH variable
export DSI_PATH="$autoDTI_HOME"/DTI_TK/matrices

##Deterministic tractography with dtk
echo -e "\n\n\nRECONSTRUCTING STREAMLINES...\n\n\n"

##Navigate to Participant's directory
cd "$output_dir"/"$PARTIC"

##Set preprocessed image input depending on whether denoising options were used
if [ -f ""$output_dir"/"$PARTIC"/iso_eddy_corrected_data_denoised.nii.gz" ]; then
    preprocessed_img='iso_eddy_corrected_data_denoised.nii.gz'
elif [ -f ""$output_dir"/"$PARTIC"/iso_eddy_corrected_data_nodenoised.nii.gz" ]; then
    preprocessed_img='iso_eddy_corrected_data_nodenoised.nii.gz'
elif [ -f ""$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz" ]; then
    preprocessed_img='eddy_corrected_data_denoised.nii.gz'
elif [ -f ""$output_dir"/"$PARTIC"/eddy_corrected_data_nodenoised.nii.gz" ]; then
    preprocessed_img='eddy_corrected_data_nodenoised.nii.gz'
else
    echo -e "\n\n\nPreprocessed image not found. Check "$output_dir"/"$PARTIC" to be sure either eddy_corrected_data_denoised.nii.gz or eddy_corrected_data_nodenoised.nii.gz actually exist. These may include an "iso_" prefix if you resliced. If not, re-run preprocessing."
    exit 0
fi
echo -e "USING "$preprocessed_img"...\n"

##Transpose bvecs rows to columns
##Read in the bvecs file
#BVECFILE=bvec
#BVECNEWFILE="bvec_dtk"
##Store it as an array
#readarray BVEC < $BVECFILE
#BVECNUM=${#BVEC[@]}
##Check the number of directions
#GRADNUM=$(echo $BVEC | wc -w )
##Indexing at i=1 so we get rid of the first vol0 indexed as 0
#if [ -f $BVECNEWFILE ]; then
#    echo -e "\n\n\n"$BVECNEWFILE" already exists. Removing and replacing...\n\n\n"
#    rm $BVECNEWFILE
#fi
#echo -e "\n\n\nTRANSPOSED BVECS IS SAVED AS "$BVECNEWFILE"\n\n\n"
#for ((i=1; i<=${GRADNUM}; i++ )); do
#        gx=$(echo ${BVEC[0]} | awk -v x=$i '{print $x}')
#        gy=$(echo ${BVEC[1]} | awk -v x=$i '{print $x}')
#        gz=$(echo ${BVEC[2]} | awk -v x=$i '{print $x}')
#    echo "$gx $gy $gz" >> $BVECNEWFILE
#done

##Add missing B0 back to first line of bvec_dtk for special cases
#echo '0 0 0' | cat - bvec_dtk > temp && mv temp bvec_dtk

##Get number of B0s
bval=`find "$output_dir"/"$PARTIC" -iname "bval" -print | head -1`
expr `grep " 0" -o "$bval" | wc -l` + 1 | echo $(xargs) > "$output_dir"/"$PARTIC"/numb0s.txt
b0s_TOTAL=`cat "$output_dir"/"$PARTIC"/numb0s.txt`

if [[ $det_type == "DTI" ]]; then
    mkdir -p "$output_dir"/"$PARTIC"/det_tractography/DTI 2>/dev/null
    cd "$output_dir"/"$PARTIC"/det_tractography/DTI
    dti_recon "$output_dir"/"$PARTIC"/"$preprocessed_img" dwi_tmp1 -gm "$output_dir"/"$PARTIC"/bvec_dtk -b 1000 -b0 $b0s_TOTAL -ot nii.gz
    wait
    dti_tracker dwi_tmp1 track_tmp2.trk -at 35 -m "$output_dir"/"$PARTIC"/bet_mask.nii.gz -m2 *_fa.nii.gz 0.15 -it nii.gz
    wait
    spline_filter track_tmp2.trk 1 dwi_dtk.trk
    wait
    trackvis dwi_dtk.trk &
    wait
    track_vis dwi_dtk.trk -l 30 -camera azimuth 0 elevation 0 -sc view1.png
    wait
    rm tmp.cam 2>/dev/null
    track_vis dwi_dtk.trk -l 30 -camera azimuth 90 elevation 0 -sc view2.png
    wait
    rm tmp.cam 2>/dev/null
    track_vis dwi_dtk.trk -l 30 -camera azimuth 0 elevation 90 -sc view3.png
    wait
    rm tmp.cam 2>/dev/null
    $FSLDIR/bin/pngappend view1.png + view2.png + view3.png DTI_tracks_3plane.png
    wait
    rm -f "$output1_dir"/"$PARTIC"/det_tractography/DTI/dwi_tmp1* 2>/dev/null
    rm -f "$output1_dir"/"$PARTIC"/det_tractography/DTI/view* 2>/dev/null

elif [[ $det_type == "ODF" ]]; then
    mkdir -p "$output_dir"/"$PARTIC"/det_tractography/ODF 2>/dev/null
        cd "$output_dir"/"$PARTIC"/det_tractography/ODF
    mkdir ODF_temp 2>/dev/null
    tail -n+2 "$output_dir"/"$PARTIC"/bvec_dtk > bvecs_noB0.txt
    hardi_mat bvecs_noB0.txt ODF_temp/temp_mat.dat -ref "$output_dir"/"$PARTIC"/"$preprocessed_img"
    wait
    export NDIRECTIONS=`wc -l "$output_dir"/"$PARTIC"/bvec_dtk | cut -d " " -f 1`
    odf_recon "$output_dir"/"$PARTIC"/"$preprocessed_img" $NDIRECTIONS 181 ODF -b0 0 -mat ODF_temp/temp_mat.dat -ot nii -iop 1 0 0 0 1 0
    wait
    odf_tracker ODF ODF_temp/tmp.trk -at 35 -m "$output_dir"/"$PARTIC"/bet_mask.nii 0.15 -it nii
    wait
    spline_filter ODF_temp/tmp.trk 1 ODF_tracks.trk
    wait
    track_vis ODF_tracks.trk -l 30 -camera azimuth 0 elevation 0 -sc view1_ODF.png
    wait
    rm tmp.cam
    track_vis ODF_tracks.trk -l 30 -camera azimuth 90 elevation 0 -sc view2_ODF.png
    wait
    rm tmp.cam
    track_vis ODF_tracks.trk -l 30 -camera azimuth 0 elevation 90 -sc view3_ODF.png
    wait
    rm tmp.cam
    $FSLDIR/bin/pngappend view1_ODF.png + view2_ODF.png + view3_ODF.png ODF_tracks_3plane.png
    wait
fi    

rm -f "$output_dir"/"$PARTIC"/numb0s.txt 2>/dev/null

exit 0
