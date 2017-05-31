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
Study=${4}
bpx=${5}
NumCores=${6}
parallel_type=${7}
NumCoresMP=${8}
NLSAM=${9}
tensor=${10}
gpu=${11}
max_gpu_threads=${12}
debug=${13}


######################Advanced Configuration Options####################
max_num_threads=45 ##Max number of jobs that can be submitted simultaneously on cluster
########################################################################

##Exit if run without FEED_openDTI.sh
if [ $# -eq 0 ]; then
    echo -e "\n\n\nYou must run openDTI by feeding command-line inputs to FEED_openDTI.sh. Type: FEED_openDTI.sh -h for command-line options. See README.txt for more instructions.\n\n\n"
    exit 1
fi

##Check if debug mode activated
if [[ $debug == 1 ]]; then
    set -x
fi

##Log to runlog_PARTIC
exec &> >(tee -i "$output_dir"/"$PARTIC"/logs/runlog_"$PARTIC".txt)
exec 2>&1

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

##Run tensor fitting using FSL's DTIFIT
if [[ $tensor == 1 ]]; then
   
    if [[ "$preprocessed_img" == "iso_eddy_corrected_data_denoised.nii.gz" ]] || [[ $preprocessed_img == "iso_eddy_corrected_data_nodenoised.nii.gz" ]]; then
        bet "$preprocessed_img" "$output_dir"/"$PARTIC"/iso_bet.nii.gz -m -f 0.2
        bet_mask_img="$output_dir"/"$PARTIC"/iso_bet_mask.nii.gz
    else
        bet_mask_img="$output_dir"/"$PARTIC"/bet_mask.nii.gz
    fi 
    ##DTIFIT
    echo -e "\n\n\nRUNNING DTIFIT...\n\n\n"
    dtifit -k "$preprocessed_img" -o "$PARTIC" -m $bet_mask_img -r bvec -b bval
    wait
fi

##Run BedpostX
if [[ $bpx == 1 ]]; then
   
    echo -e "\n\n\nRUNNING BEDPOSTX...\n\n\n"    
    ##Delete any existing bedpostx directory and start from scratch
    if [ ! -d "$output_dir"/"$PARTIC"/"bedpostx_"$PARTIC"" ]; then
        mkdir "$output_dir"/"$PARTIC"/"bedpostx_"$PARTIC""
    elif [ -d "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC" ]; then
        echo -e "\n\n\nFOUND EXISTING BEDPOSTX RUN. DELETING...\n\n\n"
        rm -rf "$output_dir"/"$PARTIC"/"bedpostx_"$PARTIC"" 2>/dev/null
        rm -rf "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC".bedpostX 2>/dev/null
        mkdir "$output_dir"/"$PARTIC"/"bedpostx_"$PARTIC""
    fi
    wait
    
    ##Copy preprocessed image, bet_mask, bval, and bvec to bedpostx directory
    cp "$preprocessed_img" "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC"/data.nii.gz 2>/dev/null
    if [[ "$preprocessed_img" == "iso_eddy_corrected_data_denoised.nii.gz" ]] || [[ $preprocessed_img == "iso_eddy_corrected_data_nodenoised.nii.gz" ]]; then
	bet "$preprocessed_img" "$output_dir"/"$PARTIC"/iso_bet.nii.gz -m -f 0.2
	cp "$output_dir"/"$PARTIC"/iso_bet_mask.nii.gz "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC"/nodif_brain_mask.nii.gz 2>/dev/null
    else 
        cp "$output_dir"/"$PARTIC"/bet_mask.nii.gz "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC"/nodif_brain_mask.nii.gz 2>/dev/null
    fi
    cp "$output_dir"/"$PARTIC"/bvec "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC"/bvecs 2>/dev/null
    cp "$output_dir"/"$PARTIC"/bval "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC"/bvals 2>/dev/null
    wait

##SGE/BEOWULF CLUSTER LEGACY SCRIPTS
##    if [[ $gpu == 1 ]]; then
##SGE/BEOWULF CLUSTER LEGACY SCRIPTS
##        if [ "`qstat -q "$FSLGECUDAQ" | wc -l`" -lt "2" ]; then
##            run_gpu=1
##        else
	    ##Generate random true/false value for submitting bedpostx using mpi (with probability "x") or bedpostx_gpu (with a probability "y") weighted selection, respectively		    
##	    x=0.30 #(probability of job being submitted using openMP)
##	    y=0.70 #(probability of job being submitted using GPU)

	    ##Run random binary number generator (weighted selection) using python numprun_gpu=`randbinary.py "$x" "$y"`
##	    run_gpu=`randbinary.py "$x" "$y"`
##	    wait
##        fi
##    fi

    ##Run bedpostx
    if [[ $parallel_type == 'SGE' ]] || [[ $parallel_type == 'PBS' ]] || [[ $parallel_type == 'SLURM' ]]; then
        ##Hashtag out for legacy scripts
        run_gpu=0
        if [[ $gpu == 1 ]] && [[ $run_gpu == 1 ]]; then
##SGE/BEOWULF CLUSTER LEGACY SCRIPTS
##            until [ "`qstat -q "$FSLGECUDAQ" | wc -l`" -lt "$max_gpu_threads" ]; do
##                sleep 2
##            done
            bedpostx "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC" -n 3 -Q "$FSLGECUDAQ"
        else
	    if [[ $parallel_type == 'SLURM' ]]; then
                until [ $(squeue -u `whoami` | wc -l) -lt $max_num_threads ]; do
                    sleep 10
                done
            fi
            bedpostx "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC" -n 3 -c
        fi
        #timeout 10 watch --interval=0.5 qstat
    elif [[ $parallel_type == 'none' ]] || [[ $parallel_type == 'Null' ]]; then
        if [[ $gpu == 1 ]]; then
            bedpostx_gpu "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC" -n 3
        else
            bedpostx "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC" -n 3 -c
        fi
    fi

    #until [ -f "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC".bedpostX/xfms/eye.mat ]; do
    #    sleep 5
    #done
    #wait    
    exit 1
fi

exit 0
