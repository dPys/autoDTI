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
tracula=${5}
NumCores=${6}
parallel_type=${7}
NumCoresMP=${8}
tracdir=${9}
debug=${10}

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

##Quality control freesurfer parcellation
##Ensure freesurfer recon is complete before continuing to QA
echo -e "\n\n\nWaiting for completed FREESURFER recon before resuming with QA...\n\n\n"
trap "exit" INT
until grep -q "finished without error" ""$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/scripts/recon-all.log"; do
    sleep 5
done
echo -e "\n\n\nCHECKING FOR FREESURFER RECON COMPLETION...\n\n\n"
##QA for FREESURFER recon
echo -e "\n\n\nRunning Quality Assessment of FREESURFER recon..."
echo -e "\n\n\nIt is highly recommended that you check generated snapshots of segmentation and parcellation maps for obvious signs of error and fix accordingly using tkmedit and recon-all re-runs. An accurate aparc+aseg image is especially critical for TRACULA.\n\n\n"
export SUBJECTS_DIR="$Study"/"$tracdir"/diffusion_recons
export QA_TOOLS="$autoDTI_HOME"/QAtools
$QA_TOOLS/recon_checker -s ""$PARTIC"" -snaps-only 

echo -e "\n\n\nPress [1] to correct the wm recon. Press any other key to skip this correction. If correcting wm.mgz, ensure that you save the correction as wm.mgz in the subject's recon mri/ directory.\n\n\n"; read WHITE
if [[ $WHITE == 1 ]]; then
    tkmedit $PARTIC brainmask.mgz -aux wm.mgz -surfs
fi

echo -e "\n\n\nPress [1] to correct the aseg recon. Press any other key to skip this correction.If correcting aparc+aseg.mgz, ensure that you save the correction as aparc+aseg.mgz in the subject's recon mri/ directory.\n\n\n"; read ASEG
if [[ $ASEG == 1 ]]; then        
    tkmedit $PARTIC brainmask.mgz -aux aseg.mgz -surfs
fi

echo -e "\n\n\nPress [1] if recon quality is acceptable. Press [2] to re-run recon-all after performing manual wm edits only. Press [3] to re-run recon-all after performing manual aseg edits only. Press [4] to re-run recon-all after performing both manual wm edits and manual aseg edits."; read RERUN
if [[ $RERUN == 1 ]]; then
    echo -e "\n\n\nSkipping recon re-reconstruction...\n\n\n"
elif [[ $RERUN == 2 ]]; then
    recon-all -subjid $PARTIC -autorecon2-wm
elif [[ $RERUN == 3 ]]; then
    recon-all -subjid $PARTIC -autorecon2-noaseg
elif [[ $RERUN == 4 ]]; then    
    recon-all -subjid $PARTIC -autorecon2-wm -autorecon2-noaseg
fi

exit 0
