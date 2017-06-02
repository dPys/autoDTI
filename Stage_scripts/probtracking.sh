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
PARTIC=${1}
Study=${2}
NumCores=${3}
parallel_type=${4}
NumCoresMP=${5}
tracdir=${6}
prep_nodes=${7}
debug=${8}

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

SUBJECTS_DIR="$Study"/"$tracdir"/diffusion_recons
export SUBJECTS_DIR
source $FREESURFER_HOME/SetUpFreeSurfer.sh

if [[ $prep_nodes == 1 ]]; then
    ##Remove pre-existing .nii.gz files in label and create new binarized volumes
    rm -f $SUBJECTS_DIR/"$PARTIC"/label/*.nii.gz 2>/dev/null
    rm -rf $SUBJECTS_DIR/"$PARTIC"/anat_reg

    ##Remove prep_nodes completion log file
    rm -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/prep_nodes.txt 2>/dev/null


    mri_annotation2label --subject "$PARTIC" --hemi lh --annotation $SUBJECTS_DIR/"$PARTIC"/label/lh.aparc.a2009s.annot --outdir $SUBJECTS_DIR/"$PARTIC"/label --surface white
    wait

    mri_annotation2label --subject "$PARTIC" --hemi rh --annotation $SUBJECTS_DIR/"$PARTIC"/label/rh.aparc.a2009s.annot --outdir $SUBJECTS_DIR/"$PARTIC"/label --surface white
    wait

    ##Remove pre-existing anat_reg and create new anat_reg directory
    if [ -d $SUBJECTS_DIR/"$PARTIC"/anat_reg ]; then
        rm -rf $SUBJECTS_DIR/"$PARTIC"/anat_reg 2>/dev/null
        mkdir -p $SUBJECTS_DIR/"$PARTIC"/anat_reg
        wait
    else
        mkdir -p $SUBJECTS_DIR/"$PARTIC"/anat_reg
        wait
    fi

    mri_convert $SUBJECTS_DIR/"$PARTIC"/mri/rawavg.mgz $SUBJECTS_DIR/"$PARTIC"/anat_reg/str.nii.gz
    wait

    mri_convert $SUBJECTS_DIR/"$PARTIC"/mri/orig.mgz $SUBJECTS_DIR/"$PARTIC"/anat_reg/fs.nii.gz
    wait

    mri_binarize --i $SUBJECTS_DIR/"$PARTIC"/mri/aparc+aseg.mgz --ventricles --o $SUBJECTS_DIR/"$PARTIC"/anat_reg/ventricles.nii.gz
    wait

    ##transform filenames
    fs2str="$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/xfms/fs2str.mat
    str2fs="$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/xfms/str2fs.mat
    fa2fs="$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/xfms/fa2fs.mat
    fs2fa="$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/xfms/fs2fa.mat
    fa2str="$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/xfms/fa2str.mat
    str2fa="$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/xfms/str2fa.mat

    ##register structurual to Fs
    tkregister2 --mov $SUBJECTS_DIR/"$PARTIC"/anat_reg/fs.nii.gz --targ $SUBJECTS_DIR/"$PARTIC"/anat_reg/str.nii.gz --regheader --reg /tmp/junk --fslregout $fs2str --noedit
    wait

    ##invert to create str2fs
    convert_xfm -omat $str2fs -inverse $fs2str
    wait

    ##Now transforming FA to structural:
    flirt -in "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/dtifit_FA.nii.gz -ref $SUBJECTS_DIR/"$PARTIC"/anat_reg/fs.nii.gz -omat $fa2str -dof 6
    wait

    ##invert to create str2fa
    convert_xfm -omat $str2fa -inverse $fa2str
    wait

    ##Concatenate and inverse
    convert_xfm -omat $fa2fs -concat $str2fs $fa2str
    wait
    convert_xfm -omat $fs2fa -inverse $fa2fs
    wait

    ##Remove pre-existing probtrackx and create new probtrackx directory
    if [ -d "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx ]; then
        rm -rf "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx 2>/dev/null
        mkdir -p "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx
        wait
    else
        mkdir -p "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx
        wait
    fi

    cp $autoDTI_HOME/Stage_scripts/node_list.txt "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/label_order.txt 2>/dev/null
    wait
 
    rm -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/seeds.txt 2>/dev/null 
    seed_list="$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/seeds.txt

    source $FREESURFER_HOME/SetUpFreeSurfer.sh

    ##Extract volumes from labels in parallel
    for lab in `cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/label_order.txt`; do
        label=$SUBJECTS_DIR/"$PARTIC"/label/"$lab".label
        vol=${label/%.label/.nii.gz}
        echo "converting "$label" to $vol"
        fsl_sub -l /dev/null -q short.q mri_label2vol --label "$label" --temp $SUBJECTS_DIR/"$PARTIC"/anat_reg/fs.nii.gz --o "$vol" --identity --fillthresh 0.5
	echo "$vol" >> $seed_list
    done
    wait

    rm -f $Study/$tracdir/tractography_output/$PARTIC/probtrackx/waypoints.txt 2>/dev/null

    ##Create binarized wm mask
    mri_binarize --i $SUBJECTS_DIR/"$PARTIC"/mri/aparc+aseg.mgz --match 2 --o $SUBJECTS_DIR/"$PARTIC"/anat_reg/wm.lh.nii.gz
    wait

    mri_binarize --i $SUBJECTS_DIR/"$PARTIC"/mri/aparc+aseg.mgz --match 41 --o $SUBJECTS_DIR/"$PARTIC"/anat_reg/wm.rh.nii.gz
    wait

    ##Add left and right wm masks together
    fslmaths $SUBJECTS_DIR/"$PARTIC"/anat_reg/wm.lh.nii.gz -add $SUBJECTS_DIR/"$PARTIC"/anat_reg/wm.rh.nii.gz $SUBJECTS_DIR/"$PARTIC"/anat_reg/wm_mask.nii.gz
    wait
    echo $SUBJECTS_DIR/"$PARTIC"/anat_reg/wm_mask.nii.gz >> "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/waypoints.txt
    wait
    touch "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/prep_nodes.txt
    wait
fi

umask 002

##Run Probtrackx for each seed mask ROI
filelines_ROIS_probtrackx=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/label_order.txt`
numseeds=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/label_order.txt | wc -l`
for seed in $filelines_ROIS_probtrackx; do
    seed_mask="$seed".nii.gz
    echo -e "\n\n\nStarting tracking for region: "$seed_mask"...\n\n\n"
    fsl_sub -l /dev/null -s omp_pe -n=4 probtrackx2 -x $SUBJECTS_DIR/"$PARTIC"/label/"$seed_mask" -s "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/merged -m "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/nodif_brain_mask -l --usef --os2t --s2tastext -c 0.2 -S 2000 --steplength=0.5 -P 5000 --fibthresh=0.01 --distthresh=0.0 --sampvox=0.0 --xfm="$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX/xfms/fs2fa.mat --meshspace=freesurfer --waypoints=$Study/$tracdir/tractography_output/$PARTIC/probtrackx/waypoints.txt --waycond='OR' --avoid=$SUBJECTS_DIR/"$PARTIC"/anat_reg/ventricles.nii.gz --seedref=$SUBJECTS_DIR/"$PARTIC"/anat_reg/fs.nii.gz --forcedir --opd --omatrix1 --dir="$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/paths_"$seed" --targetmasks="$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/seeds.txt
    #sleep 200
done
wait

echo -e "\n\n\nWAITING FOR PROBTRACKX RESULTS...\n\n\n"

##Rename matrix_seeds_to_all_targets to .asc
for seed in $filelines_ROIS_probtrackx; do
    mv "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/paths_"$seed"/matrix_seeds_to_all_targets "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/paths_"$seed"/matrix_seeds_to_all_targets.asc 2>/dev/null &
done
wait

BASE_loc=""$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx"
LABELS_loc=""$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/label_order.txt"
ROIS_loc="$SUBJECTS_DIR/"$PARTIC"/label"

##Build connectome adjancency matrix
python $autoDTI_HOME/Py_function_library/connectome_plot.py $BASE_loc $LABELS_loc $ROIS_loc

exit 0
