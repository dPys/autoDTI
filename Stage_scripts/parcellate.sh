#!/bin/bash
#    openDTI: A dMRI pipeline for efficient and comprehensive DTI analysis
#    Copyright (C) 2016  AUTHOR: Derek Pisner
#    Contributors: Adam Bernstein, Aleksandra Klimova, Matthew Allbright
#
#    openDTI is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published
#    by the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    openDTI is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the complete GNU Affero General Public
#    License with openDTI in a file called LICENSE.txt. If not, and/or you simply have
#    questions about licensing and copyright/patent restrictions with openDTI, please
#    contact the primary author, Derek Pisner, at dpisner@utexas.edu

##Variable inputs
output_dir=${1}
PARTIC=${2}
sequence=${3}
T1directory=${4}
Study=${5}
parcellate=${6}
NumCores=${7}
parallel_type=${8}
NumCoresMP=${9}
tracdir=${10}
gpu=${11}
omp_pe=${12}
max_gpu_threads=${13}
conversion_type=${14}
debug=${15}
ALLOCATION=${16}

##Exit if run without FEED_openDTI.sh
if [ $# -eq 0 ]; then
    echo -e "\n\n\nYou must run openDTI by feeding command-line inputs to FEED_openDTI.sh. Type: FEED_openDTI.sh -h for command-line options. See README.txt for more instructions.\n\n\n"
    exit 0
fi

##Check if debug mode activated
if [[ $debug == 1 ]]; then
    set -x
fi

##Log to runlog_PARTIC
exec &> >(tee -i "$output_dir"/"$PARTIC"/logs/runlog_"$PARTIC".txt)
exec 2>&1

##Create TRACULA output folder for special sequence types
if [ ! -d "$Study"/"$tracdir"/diffusion_recons ]; then
    mkdir -p "$Study"/"$tracdir"/diffusion_recons
fi

##Anatomical prep
if [ ! -f "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"_Anatomical.nii ] && [ ! -f "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/mri/orig/001.mgz ]; then
    ##Convert anatomical to NIFTI
    if [[ $conversion_type == "dcm2niix" ]]; then
	dcm2niix -z n "$T1directory"
	wait
    elif [[ $conversion_type == "mriconvert" ]]; then
        mcverter "$T1directory" -o "$T1directory" -f fsl -d -n -q
        wait
    fi

    ##Rename converted nifti file and copy it to diffusion_recons
    T1=`find "$T1directory" -not -iname "co*" -not -iname "o*" -iname '*.nii' -print | sed 's/.*\///'`
    mv "$T1directory"/"$T1" "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"_Anatomical.nii 2>/dev/null
    wait
fi

##Display error if T1 base image is missing
if [ ! -f "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"_Anatomical.nii ] && [ ! -f "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/mri/orig/001.mgz ]; then
    echo -e "\n\n\nERROR: NO ANATOMICAL SELECTED FOR THIS PARTICIPANT! IF YOU WISH TO USE A REPEAT \nANATOMICAL IMAGE PLEASE NAME IT WITH THE 'PARTIC#'_Anatomical.nii AND \nENSURE RAW DICOMS FOR T1 ARE LOCATED IN THE SELECT T1 FOLDER. \nCHECK FEED_openDTI.sh FOR DEBUGGING T1 FILE LOCATION."
    exit 0
fi

##Convert Anatomical to .mgz
if [ ! -d "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/mri/orig ]; then    
    mkdir -p "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/mri/orig
fi
if [ ! -f "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/mri/orig/001.mgz ]; then
    mri_convert --in_type nii --out_type mgz --out_orientation RAS "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"_Anatomical.nii "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/mri/orig/001.mgz
fi
wait

##Source FREESURFER_HOME with SUBJECTS_DIR directory
export SUBJECTS_DIR=""$Study"/"$tracdir"/diffusion_recons"
source $FREESURFER_HOME/SetUpFreeSurfer.sh

##Re-start recon by deleting log entry
rm "$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/scripts/IsRunning.lh+rh 2>/dev/null

##SGE/BEOWULF CLUSTER LEGACY SCRIPTS
##if [[ $gpu == 1 ]]; then
##    if [ "`qstat -q "$FSLGECUDAQ" | wc -l`" -lt "2" ]; then
##        run_gpu=1
##    else
##	##Generate random true/false value for submitting recon-all with GPU acceleration (with probability "y") or not (with a probability "x") weighted selection, respectively
##	x=0.2 #(probability of job being submitted using no GPU acceleration)
##	y=0.8 #(probability of job being submitted using GPU)
##
##	##Run random binary number generator (weighted selection) using python numpy
##	run_gpu=`randbinary.py "$x" "$y"`
##	wait
##    fi
#fi

if [[ $parallel_type == 'SGE' ]] || [[ $parallel_type == 'PBS' ]] || [[ $parallel_type == 'SLURM' ]]; then
    ##Hashtag out for legacy scripts
    run_gpu=0
    if [[ $gpu == 1 ]] && [[ $run_gpu == 1 ]]; then
##SGE/BEOWULF CLUSTER LEGACY SCRIPTS
##        echo "Freesurfer does not currently support gpu acceleration in recent CUDA versions"
##        until [ "`qstat -q "$FSLGECUDAQ" | wc -l`" -lt "$max_gpu_threads" ]; do
##            sleep 2
##        done
        fsl_sub -l "$Study"/"$tracdir"/diffusion_recons/"$PARTIC" -s omp_pe,"$NumCoresMP" -N recon_"$PARTIC" -T 2880 -q "$FSLGECUDAQ" recon-all -all -s "$PARTIC" -no-isrunning -openmp "$NumCoresMP" -use-gpu
    else
        ##Submit recon to batch queue
        fsl_sub -l "$Study"/"$tracdir"/diffusion_recons/"$PARTIC" -s omp_pe,"$NumCoresMP" -N recon_"$PARTIC" -T 1440 -A $ALLOCATION recon-all -subjid "$PARTIC" -all -no-isrunning -parallel -openmp $NumCoresMP
    fi
elif [[ $parallel_type == 'none' ]] || [[ $parallel_type == 'Null' ]]; then
##SGE/BEOWULF CLUSTER LEGACY SCRIPTS
#    ##Ensure safe cpu load levels before running recon-all with the openmp flag
#    trigger=30.00
#    load=`cat /proc/loadavg | awk '{print $1}'`
#    response=`echo | awk -v T=$trigger -v L=$load 'BEGIN{if ( L > T){ print "greater"}}'`
#    if [[ $response == greater ]]; then
#        echo -e "\n\n\nWaiting for cpu load to go down before continuing with NLSAM denoising...\n\n\n"
#    fi
#    until [[ $response != greater ]]; do
#        sleep 5
#        load=`cat /proc/loadavg | awk '{print $1}'`
#        response=`echo | awk -v T=$trigger -v L=$load 'BEGIN{if ( L > T){ print "greater"}}'`
#    done      
##   if [[ $gpu == 1 ]] && [[ $run_gpu == 1 ]]; then
##        ##Run recon new terminal window
##        gnome-terminal --tab -e "bash -c \"recon-all -all -s "$PARTIC" -use-gpu; exec bash\"" &
##
##    else
##        ##Run recon new terminal window
##        gnome-terminal --tab -e "bash -c \"recon-all -all -s "$PARTIC"; exec bash\"" &
##
##        ##Run recon in background if new terminal window is undesireable -- *Note: this risk creating a runaway process; Also, ensure that you hashtag the prior gnome-terminal command.
        recon-all -all -s "$PARTIC" -no-isrunning
##    fi
fi

exit 0
