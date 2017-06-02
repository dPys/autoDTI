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
output_dir=${6}
debug=${7}

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
exec &> >(tee -i "$output_dir"/"$PARTIC"/parallel_logs/runlog_"$PARTIC".txt)
exec 2>&1

##This stage is optional and, with the exception of FAST segmentations at the end, is already automatically included in the recon -all step that runs with parcellate.sh. If for some reason a complete reconstruction fails at surface stages, or you simply wish to create a pial surface for visualization purposes, this stage can be run without a complete recon

##Check if surface directory already exists in output_dir. If not, then create it.
if [ ! -d "$output_dir"/"$PARTIC"/surface ]; then 
    mkdir "$output_dir"/"$PARTIC"/surface
fi

export SUBJECTS_DIR="$output_dir"/"$PARTIC"/surface
source $FREESURFER_HOME/SetUpFreeSurfer.sh

##Build Pial Surface
echo -e "Building pial surface...\n\n\n"
rm -f "$output_dir"/"$PARTIC"/surface/scripts/IsRunning.lh+rh 2>/dev/null

##Run surface recon in case original recon was partial
recon-all -autorecon-pial -subjid $PARTIC -sd "$output_dir"/"$PARTIC"/surface

##Register surface files to diffusion space
for i in `ls "$output_dir"/"$PARTIC"/surface`; do
    flirt -in "$output_dir"/"$PARTIC"/surface/"$i" -ref "$output_dir"/"$PARTIC"/bet_mask.nii.gz -out "$output_dir"/"$PARTIC"/surface_diff/"$i"_diff -bins 256 -cost normmi -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp trilinear &
done

exit 0
