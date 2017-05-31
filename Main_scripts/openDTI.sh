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

export LC_ALL=C

##################################### BODY ###########################################

## 5) Variables received from FEED_openDTI.sh (Add variables to this list and FEED_openDTI.sh as necessary to expand/customize). NOTE: ORDER MATTERS (I.E. MUST CORRESPOND TO THE ORDER SUPPPLIED AT THE END OF FEED_openDTI.sh AND ALL VARIABLES BEING RECEIVED CANNOT BE EMPTY!):

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
dwi_dir=${1} ##Source directory for DWI raw dicoms
P2A=${2} ##Source directory for P2A B0 raw dicoms
output_dir=${3} ##Directory where preprocessing is conducted. Unless manually altered, this should be called "dti_preproc"
OddSlices=${4} ##Value equal to 1 or 2 specifying which slice (bottom or top) should be removed from data during TOPUP/new EDDY in cases of odd slices
PARTIC=${5} ##Participant ID used to label folders and files
sequence=${6} ##Number corresponding to a sequence acceleration factor (e.g. multiband 2 or 3) or any arbitrary number you wish to distinguish analysis runs when using data from differing sequence types
T1directory=${7} ##Source directory for T1 MPRAGE raw dicoms
Study=${8} ##A base folder (must actually exist) where openDTI will run its operations
preproc=${9} ##Binary switch variable to indicate whether or not preprocessing will be run
tracula=${10} ##Binary switch variable to indicate whether or not tracula will be run
buildsurf=${11} ##Binary switch variable to indicate whether or not surface reconstruction will be run
probtracking=${12} ##Binary switch variable to indicate whether or not connectome mapping will be run
eddy_type=${13} ##Binary switch variable to indicate whether old eddy_correct or new eddy with TOPUP will be run
bpx=${14} ##Binary switch variable to indicate whether or not bedpostx will be run
parcellate=${15} ##Binary switch variable to indicate whether or not FREESURFER reconstruction will be run
stats=${16} ##Binary switch variable to indicate whether or not key metrics from tracula and freesurfer output will be extracted to a .csv file
NumCores=${17} ##Number of cores to be used in the pipeline run. *Note: If the -n flag is used, however, it will override the default specified in FEED_openDTI.sh configuration options section.
E_switch=${18} ##Binary switch variable to indicate whether or not to run new Eddy after -avr check has been performed with old eddy_correct
NRRD=${19} ##Binary switch variable to indicate whether or not .NRRD conversion will be run
parallel_type=${20}  ##variable indicating the job scheduler type used if batch queueing system is installed. This is defined in FEED_openDTI.sh configuration options section.
QA=${21} ##Binary switch variable to indicate whether or not FREESURFER's Quality Assessment tool will be run
NumCoresMP=${22} ##Number of LOCAL cores to be used in the pipeline run. This is detected automatically in FEED_openDTI.sh
NLSAM=${23} ##Binary switch variable to indicate whether or not NLSAM denoising will be run
noconv=${24} ##Binary switch variable to indicate whether or not dicom-nifti conversion of the raw dwi image should be skipped for this run
after_eddy=${25} ##Binary switch variable to indicate whether or not eddy correction should be skipped for this run
det_tractography=${26} ##Binary switch variable to indicate whether or not deterministic tractography will be run
fieldmap=${27} ##Variable to indicate whether or not to use a fieldmap correction. This turns on automatically when raw fieldmap dicoms are supplied to -rawMAG and -rawPHASE flags. A value of "1" will run fieldmap correction and a value of "2" assumes fieldmap correction has already been run, but you want to continue preprocessing following fieldmap correction   
mag_dir=${28} ##Path to directory containing raw fieldmap (Magnitude) dicoms
phase_dir=${29} ##Path to directory containing raw fieldmap (Phase) dicoms
rotate_bvecs=${30} ##Binary switch variable to indicate whether or not to rotate bvec file after eddy correction
tensor=${31} ##Binary switch variable to indicate whether or not tensor fitting (i.e. DTIFIT) will be run
volrem=${32} ##Variable equal to the value of a single direction volume suspected to contain excess movement to be removed
auto_volrem=${33} ##Binary switch variable to indicate whether or not automatic high-motion volume removal will be run
dwell=${34} ##dwell time value (for fieldmap correction)
det_type=${35} ##Type of deterministic tractography ("DTI" or "ODF")
gpu=${36} ##Trigger gpu-enabled function routines
reinit_check=${37} ##Reinitialize TRACULA for missing or incomplete tracts
omp_pe=${38} ##openMP queue and threads
view_outs=${39} ##View outputs for each stage in fslview/freeview
max_gpu_threads=${40} ##Maximum number of GPU slots available
TE=${41} ##TE value (for fieldmap correction)
conversion_type=${42} ##Type of dicom-nifti conversion (i.e. dcm2niix or mriconvert's mcverter)
SCANNER=${43} ##Scanner type (only important for running fieldmap correction and NLSAM denoising)
Numcoils=${44} ##Number of coils used in scan acquisition (optional for improving the performance of NLSAM denoising)
starting=${45} ##For script run timing
NRRD=${46} ##Convert preprocessed image to .nrrd format
prep_nodes=${47} ##Generate 3d volums of freesurfer parcellation/ sub-cortical segmentation labels for use as nodes in connectome seed mask
ALLOCATION=${48} ##Allocation project name
debug=${49} ##Activate debug mode
reslice=${50} ##Active conversion to isotropic voxels
TOTAL_READOUT=${51} ##Total readout value (for topup/eddy) 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

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

##Set tracdir directory, even if tractography is not being run
if [[ $sequence > 1 ]]; then
    tracdir="TRACULA_MB"$sequence""
elif [[ $sequence == 1 ]]; then
    tracdir="TRACULA"
fi

if [[ $tracula == 1 ]]; then
    echo -e "\n\n\nTRACULA DATA WILL BE OUTPUT TO "$Study"/"$tracdir"...\n\n\n"
fi

##################################################################
###################PARCELATION / SEGMENTATION#####################
##################################################################
##Give Freesurfer a headstart if recon has not yet been completed
if [[ $parcellate == 1 ]]; then
    ##Cortical Reconstruction for diffusion_recons
    if grep -q "finished without error" ""$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/scripts/recon-all.log" 2>/dev/null; then
        echo -e "\n\n\nRECONSTRUCTION ALREADY COMPLETED. SKIPPING...\nTo remove existing, enter: rm -rf ""$Study"/"$tracdir"/diffusion_recons/"$PARTIC""\n\n\n"
    elif grep -q "finished with errors" ""$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/scripts/recon-all.log" 2>/dev/null; then
        echo -e "\n\n\nRECONSTRUCTION CONTAINS ERRORS. CHECK LOGS. DO YOU HAVE A DIFFERENT T1 MPRAGE IMAGE TO USE?"
        exit 0
    else
        echo -e "\n\n\nRUNNING CORTICAL RECONSTRUCTION STAGE...\n\n\n"
	parcellate.sh "$output_dir" "$PARTIC" $sequence "$T1directory" "$Study" $parcellate $NumCores $parallel_type $NumCoresMP "$tracdir" $gpu "$omp_pe" $max_gpu_threads "$conversion_type" "$debug" "$ALLOCATION" &
    fi
elif [[ $parcellate == 0 || $parcellate == 'Null' ]]; then
    echo -e "\n\n\nFREESURFER RECONSTRUCTION SKIPPED!\n\n\n"
fi

##################################################################
###################RECONSTRUCT PIAL SURFACE#######################
##################################################################
if [[ $buildsurf == 1 ]]; then
    echo -e "\n\n\nBUILDING PIAL SURFACE...\n\n\n"
    buildsurf.sh "$PARTIC" "$Study" $NumCores $parallel_type $NumCoresMP "$output_dir" "$debug" &
fi

##################################################################
###########################PREPROCESSING##########################
##################################################################
if [[ $preproc == 1 ]]; then    
    echo -e "\n\n\nRUNNING PREPROCESSING for "$PARTIC"...\n\n\n"
    preprocess.sh "$dwi_dir" "$P2A" "$output_dir" "$OddSlices" "$PARTIC" "$sequence" "$T1directory" "$Study" "$preproc" "$tracula" "$buildsurf" "$probtracking" "$eddy_type" "$bpx" "$parcellate" "$stats" "$NumCores" "$E_switch" "$NRRD" "$parallel_type" "$QA" "$NumCoresMP" "$NLSAM" "$noconv" "$after_eddy" "$det_tractography" "$fieldmap" "$mag_dir" "$phase_dir" "$rotate_bvecs" "$tensor" "$volrem" "$auto_volrem" "$dwell" "$det_type" "$gpu" "$reinit_check" "$omp_pe" "$view_outs" "$max_gpu_threads" "$TE" "$conversion_type" "$SCANNER" "$Numcoils" "$starting" "$NRRD" "$prep_nodes" "$debug" "$ALLOCATION" "$reslice" "$TOTAL_READOUT"
    trap "exit" INT
    until [ -f "$output_dir"/"$PARTIC"/"DONE_PREPROCESSING" ]; do
             sleep 5
    done
    
    if [ -f "$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz ]; then
        preprocessed_img=eddy_corrected_data_denoised.nii.gz
    elif [ -f "$output_dir"/"$PARTIC"/eddy_corrected_data_nodenoised.nii.gz ]; then
        preprocessed_img=eddy_corrected_data_nodenoised.nii.gz
    fi

    if [[ $view_outs == 1 ]]; then
        ##Display preprocessing quality assessment instructions
        echo -e "\n\n\nInspect preprocessing result and compare to original_data.nii.gz. Then, close fslview and type the [enter] key to continue.\n\n\n"
        ##View preprocessed image to ensure usability
        fslview "$output_dir"/"$PARTIC"/original_data.nii.gz "$output_dir"/"$PARTIC"/$preprocessed_img &
    fi

elif [[ $preproc == 0 || $preproc == 'Null' ]]; then
    echo -e "\n\n\nPREPROCESSING SKIPPED!\n\n\n"
fi

###################################################################
####################DETERMINSTIC TRACTOGRAPHY######################
###################################################################
if [[ $det_tractography == 1 ]]; then
    ##Check preprocessing inputs before running deterministic tractography    
    if [ ! -f ""$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz" ] && [ ! -f ""$output_dir"/"$PARTIC"/eddy_corrected_data_nodenoised.nii.gz" ]; then
        echo -e "\n\n\nERROR: Need to run preprocessing first! Minimally, you will need to run FEED_openDTI.sh using the -prep flag"
        exit 0
    fi
        
    echo -e "\n\n\nRUNNING DETERMINISTIC TRACTOGRAPHY WITH DIFFUSION TOOLKIT...\n\n\n"     
    det_tractography.sh "$output_dir" "$PARTIC" $sequence "$Study" $NumCores $parallel_type $NumCoresMP $det_type $debug
    if [ -f "$output_dir"/"$PARTIC"/det_tractography_failed.txt ]; then
        rm -f "$output_dir"/"$PARTIC"/det_tractography_failed.txt
        exit 0
    fi
fi

##################################################################
######################FSL MODEL FITTING###########################
##################################################################
##Check Inputs before tensor/ ball-and-stick fitting
if [[ $tensor == 1 || $bpx == 1 ]]; then    
    if [ ! -f ""$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz" ] && [ ! -f ""$output_dir"/"$PARTIC"/eddy_corrected_data_nodenoised.nii.gz" ]; then
        echo -e "\n\n\nERROR: Need to run preprocessing first! Minimally, you will need to run FEED_openDTI.sh using the -prep flag"
        exit 0
    fi
fi
    
##Prep for Tractography and TBSS
if [[ $tensor == 1 ]]; then
    echo -e "\n\n\nFITTING DIFFUSION MODEL AT EACH VOXEL USING TENSOR APPROACH...\n\n\n"
fi 
if [[ $bpx == 1 ]]; then
    echo -e "\n\n\nFITTING DIFFUSION MODEL AT EACH VOXEL USING BALL-AND-STICK APPROACH...\n\n\n"
fi 
if [[ $bpx == 1 || $tensor == 1 ]]; then
    diffmodelfitting.sh "$output_dir" "$PARTIC" "$sequence" "$Study" $bpx "$NumCores" $parallel_type "$NumCoresMP" $NLSAM $tensor "$gpu" "$max_gpu_threads" $debug
fi    
if [[ $tensor == 1 ]]; then
    trap "exit" INT
    until [ -f "$output_dir"/"$PARTIC"/"$PARTIC"_FA.nii.gz ]; do
        sleep 5
    done

    if [[ $view_outs == 1 ]]; then
        ##Display model-fitting quality assessment instructions
        echo -e "\n\n\nFor "$PARTIC"_V1.nii.gz, select: info (i) > 'Display as:' > 'Lines' to view crossing fibers as lines at each voxel. Ensure that the lines follow the basic anatomy of the underying white matter. e.g. in the corpus callosum (L-R), cingulum (A-P), corticospinal tract (I-S).\n\n\n"
        ##View bedpostx results to confirm accurate model fit
        fslview "$output_dir"/"$PARTIC"/"$PARTIC"_FA.nii.gz "$output_dir"/"$PARTIC"/"$PARTIC"_V1.nii.gz &
    fi
fi
if [[ $bpx == 1 ]]; then
    trap "exit" INT
    #until [ -f "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC".bedpostX/xfms/eye.mat ]; do
         #sleep 60
    #done
    #sleep 45    

    if [[ $view_outs == 1 ]]; then
	##Display model-fitting quality assessment instructions
	echo -e "\n\n\nFor dyads1 and dyads2, select: info (i) > 'Display as:' > 'Lines' to view crossing fibers as lines at each voxel. Ensure that the dyads1 lines follow the basic anatomy of the underying white matter. e.g. in the corpus callosum (L-R), cingulum (A-P), corticospinal tract (I-S).\n\n\n"
	##View bedpostx results to confirm accurate model fit
	fslview "$output_dir"/"$PARTIC"/"$PARTIC"_FA.nii.gz "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC".bedpostX/dyads1.nii.gz "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC".bedpostX/dyads2.nii.gz "$output_dir"/"$PARTIC"/"$PARTIC"_V1.nii.gz &
    fi
fi
if [[ $bpx == 0 && $tensor == 0 ]]; then
    echo -e "\n\n\nDTIFIT AND BEDPOSTX SKIPPED!\n\n\n"
fi

##################################################################
#######################FREESURFER RECON QA########################
##################################################################
if [[ $QA == 1 ]]; then
    recon_QA.sh "$output_dir" "$PARTIC" $sequence "$Study" $tracula $NumCores $parallel_type $NumCoresMP "$tracdir"
    echo -e "\n\n\nRUNNING QUALITY ASSESSMENT OF FREESURFER RECON...\n\n\n"
fi

##################################################################
##############PRE-TRACTOGRAPHY INPUT ERROR HANDLING###############
##################################################################
##Preprocessing complete
if [[ $bpx == 1 ]] && [ ! -f "$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz ] && [ ! -f "$output_dir"/"$PARTIC"/eddy_corrected_data_nodenoised.nii.gz ]; then
    echo -e "\n\n\nERROR: DWI preprocessing incomplete\n\n\n"
    exit 0
fi

##Bedpostx complete
if [ -d "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC".bedpostX ]; then
    #if [ $bpx -eq "1" ] && [ -f "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC".bedpostX/xfms/eye.mat ]; then
    if [ -f "$output_dir"/"$PARTIC"/bedpostx_"$PARTIC".bedpostX/xfms/eye.mat ]; then
        req0="1"
    else
        req0="0"
    fi
else 
    req0="0"
fi

##DTIFIT complete
if [ ! -f "$output_dir"/"$PARTIC"/"$PARTIC"_FA.nii.gz ] && [ ! -f "$output_dir"/"$PARTIC"/"$PARTIC"_MD.nii.gz ]; then
    if [[ $tensor == 0 ]]; then
        req1="0"
    elif [[ $tensor == 1 ]]; then
        req1="1"
    fi
fi

##Parcellation complete
if ! grep -q "finished without error" ""$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/scripts/recon-all.log" 2>/dev/null; then
    req2="0"
else
    req2="1"
fi

##TRACULA complete
if [ ! -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/scripts/"trac-paths.done" ]; then
    req3="0"
else
    req3="1"
fi

##Check All
if [[ $tracula == 1 ]] && [[ $req0 == "0" ]] && [[ req1 == "0" ]] && [[ req2 == "0" ]]; then
    echo -e "\n\n\nERROR: Need to run diffusion model fitting stage, i.e. -b and -t first"
    exit 0
fi

if [[ ( $stats == 1 || $probtracking == 1 ) && $req0 == "0" ]]; then
    echo -e "\n\n\nERROR: Need to run diffusion model fitting stage, i.e. -b and -t first"
    exit 0
fi

if [[ ( $stats == 1 || $probtracking == 1 ) && $req2 == 0 ]]; then
    echo -e "\n\n\nERROR: Need to run FREESURFER reconstruction stage, i.e. -f first"
    exit 0
fi

if [[ $stats == 1 && $req3 == 0 && $tracula != 1 ]]; then
    echo -e "\n\n\nERROR: Need to run TRACULA, i.e. -T first"
    exit 0
fi

##################################################################
#################GLOBAL PROBABILISTIC TRACTOGRAPHY################
##################################################################
if [[ $tracula == 1 ]] || [[ $reinit_check == 1 ]]; then
    tracula.sh "$output_dir" "$PARTIC" $sequence "$Study" $tracula $NumCores $parallel_type $NumCoresMP "$tracdir" $reinit_check $view_outs $debug
fi

###################################################################
##EXTRACT TRACT STATISTICS FROM GLOBAL PROBABILISTIC TRACTOGRAPHY##
###################################################################
if [[ $reinit_check == 1 ]] && [[ $stats == 1 ]]; then
    echo -e "\n\n\nCHECKING FOR COMPLETED TRACTOGRAPHY AND REINITIALIZATION FOR INCOMPLETE/MISSING TRACTS...\n\n\n"
    trap "exit" INT
    until [ -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/scripts/"trac-paths.done" ] && [ -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/reinit_complete.txt ]; do
        sleep 5
    done
elif [[ $stats == 1 ]]; then
    echo -e "\n\n\nCHECKING FOR COMPLETED TRACTOGRAPHY...\n\n\n"
    trap "exit" INT
    until [ -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/scripts/"trac-paths.done" ]; do
        sleep 5
    done
fi
if [[ $stats == 1 ]]; then
    echo -e "\n\n\nEXTRACTING STATS...\n\n\n" 
    stats.sh "$PARTIC" "$Study" $NumCores $parallel_type $NumCoresMP "$tracdir" $debug "$output_dir"
fi

##################################################################
####################BUILD STRUCTURAL CONNECTOME###################
##################################################################
##If connectome mapping option is set, check that prep_nodes has been run
if [[ $probtracking == 1 ]] && [[ $prep_nodes != 1 ]] && [ ! -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/probtrackx/prep_nodes.txt ]; then
    echo -e "\n\n\nERROR: Need to run prep_nodes, i.e. -pn first"
    exit 0
fi

if [[ $probtracking == 1 ]] || [[ $prep_nodes == 1 ]]; then
    echo -e "\n\n\nBUILDING STRUCTURAL CONNECTOME...\n\n\n"
    probtracking.sh "$PARTIC" "$Study" $NumCores $parallel_type $NumCoresMP "$tracdir" $prep_nodes $debug
fi

##################################################################
######################### EXIT WORKFLOW ##########################
##################################################################
if [[ $preproc == 1 ]] || [[ $tensor == 1 || $bpx == 1 ]]; then
    if [ -f ""$output_dir"/"$PARTIC"/MOTION_OUTLIERS.txt" ] && [ -f ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/dwi_snr.txt" ]; then
        cd "$output_dir"/"$PARTIC"
        sed --in-place '/Average*/d' MOTION_OUTLIERS.txt 
        echo `awk '{s+=$1}END{print "Average SNR across volumes:",s/NR}' RS=" " "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/dwi_snr.txt` >> "$output_dir"/"$PARTIC"/MOTION_OUTLIERS.txt
        cat "$output_dir"/"$PARTIC"/MOTION_OUTLIERS.txt
    elif [ -f "$output_dir"/"$PARTIC"/MOTION_OUTLIERS.txt ]; then
        cat "$output_dir"/"$PARTIC"/MOTION_OUTLIERS.txt
    fi
fi

secs=$(( SECONDS - starting ))
duration=`printf '%dh:%dm:%ds\n' $(($secs/3600)) $(($secs%3600/60)) $(($secs%60))`
echo "SPAWNED SELECTED STAGES IN "$duration""
exit 0
