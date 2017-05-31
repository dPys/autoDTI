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

##This script can be used to batch multiple subjects with openDTI (the user specified inputs must be customized to where your files are located and you must create a text file lising the participant ID's of the subejcts you wish to run). The "find" command is used to get directory paths automatically to your raw data directories, so you will have to modify those commands (i.e. for DWI_dir, P2A_dir, etc.) to be able to successfully find your raw data directory names using regular expressions. This script will feed each loop iteration to a new tab in a konsole terminal in order to keep everything contained within one window.

############USER SPECIFIED INPUTS############
Study='/data/EWM' ##Base study folder that you wish to use for openDTI
RAW_data='/data/EWM/RAW_data' ##Directory containing each subject's sequence folders (which in turn contain raw dicoms)
subjects_list='/home/scanlab/Desktop/Ryan/subjectslist_EWM.txt' ## Text file where each line is for a different subject ID
parallel_conf=1 ##Set parallel_conf equal to "1" if you are using a compute cluster with SGE/GridEngine/Univa Grid Engine and wish to monitor all nodes with htop during batch run
#############################################
subjects=`cat $subjects_list`

echo -e "\n\n\nStarting batch run...\n\n\n"
for PARTIC in $subjects; do
	echo "-------------------------------------------------------------------------------"	
	echo -e "\n\n\nRunning "$PARTIC"...\n\n\n"

	cd $RAW_data/$PARTIC

        #Remove all spaces, carrots, periods, and hyphens, replacing with underscores in raw directory names
	for f in *\ *; do mv "$f" "${f// /_}"; done 2>/dev/null
        for f in *\-*; do mv "$f" "${f//-/_}"; done 2>/dev/null
	for f in *\>*; do mv "$f" "${f//>/_}"; done 2>/dev/null
	for f in *\.*; do mv "$f" "${f//./_}"; done 2>/dev/null
	for f in *\<*; do mv "$f" "${f//</_}"; done 2>/dev/null

	############################## Auto-detect raw data directory paths using string and regular expression patterns ####################################
	DWI_dir=`find $RAW_data/$PARTIC -maxdepth 1 \( -iname "*DTI_72_DIRs_A*" -o -iname "*DTI_30_DIRs_A*" \) -not -iname "*ADC*" -not -iname "*ColFA*" -not -iname "*FA*" -not -iname "*TENSOR*" -not -iname "*TRACEW*" | tail -1`
	P2A_dir=`find $RAW_data/$PARTIC -maxdepth 1 -iname "*Bzero_verify_P*" -o -iname "*DTI_72_VERIFY_P*" -o -iname "*reversePolarityBzero*" | tail -1` ##This is for reverse phase-encoded B0's
	ANAT_dir=`find $RAW_data/$PARTIC -maxdepth 1 -iname '*T1_mprage_1mm*' | sort -r -V | tail -1`
	MAG_dir=`find $RAW_data/$PARTIC/ -maxdepth 1 -iname '*field_mapping*' | sort -r -V | tail -1`
        PHASE_dir=`find $RAW_data/$PARTIC -maxdepth 1 -iname '*field_mapping*' | sort -r -V | head -1`
	#####################################################################################################################################################

        rm -f $Study/openDTI_batch.log 2>/dev/null
        echo "Process ID is $$"
        echo ""$PARTIC" -- PID: "$$"" >> $Study/openDTI_batch.log


	##Deal with missing folders
	if [ ! -z $DWI_dir ] && [ ! -z $P2A_dir ] && [ ! -z $ANAT_dir ]; then
		echo "DWI directory is "$DWI_dir""
		echo "P2A directory is "$P2A_dir""
		echo "T1 ANATOMICAL directory is "$ANAT_dir""

		####FEED_openDTI.sh commands here####
		##From scratch, full pipeline (i.e. all available steps of preprocessing, freesurfer recon of T1 anatomical, diffusion modeling fitting with tensor and ball-and-stick models, global probabilistic tractography with TRACULA, auto quality-control of missing or incomplete tracts, tract statistics, determinsitic tractography using DTI-TK, and acceleration/parallelization using openMP, MPI, and GPU enabled tools.) 
                #konsole --noclose --profile Shell --new-tab -p tabtitle="$PARTIC" -e bash -c "source ~/.bashrc; FEED_openDTI.sh $Study -p $PARTIC -rawDWI "$DWI_dir" -rawP2A "$P2A_dir" -rawT "$ANAT_dir" -rawMAG "$MAG_dir" -rawPHASE "$PHASE_dir" -prep -avr -EC -FMC -nl -BWpe "23.321" -r -vo -t -b -f -T -reinit -stats -d -dt "DTI" -n 11 -gpu -D" 2>/dev/null &

                ##From scratch, full pipeline without deterministic tractography (i.e. all available steps of preprocessing, freesurfer recon of T1 anatomical, diffusion modeling fitting with tensor and ball-and-stick models, global probabilistic tractography with TRACULA, auto quality-control of missing or incomplete tracts, tract statistics, and acceleration/parallelization using openMP, MPI, and GPU enabled tools.) 
                #konsole --noclose --profile Shell --new-tab -p tabtitle="$PARTIC" -e bash -c "source ~/.bashrc; FEED_openDTI.sh $Study -p $PARTIC -rawDWI "$DWI_dir" -rawP2A "$P2A_dir" -rawT "$ANAT_dir" -rawMAG "$MAG_dir" -rawPHASE "$PHASE_dir" -prep -avr -EC -FMC -nl -BWpe "23.321" -r -vo -t -b -T -reinit -stats -n 11 -gpu -D" 2>/dev/null &

		##From scratch without freesurfer recon, without gpu and openmp enabled and without fieldmapping and auto-volume-removal
                #konsole --noclose --profile Shell --new-tab -p tabtitle="$PARTIC" -e bash -c "source ~/.bashrc; FEED_openDTI.sh $Study -p $PARTIC -rawDWI "$DWI_dir" -rawP2A "$P2A_dir" -prep -BWpe "23.321" -EC -r -t -b -T -reinit -stats" 2>/dev/null &


                
		##Commence pipeline after dicom-to-nifti conversion and after eddy correction (e.g. if you are starting with raw .nii files as opposed to raw dicoms)
                #konsole --noclose --profile Shell --new-tab -p tabtitle="$PARTIC" -e bash -c "source ~/.bashrc; FEED_openDTI.sh $Study -p $PARTIC -prep -rawDWI "$DWI_dir" -nc -nl -t -r -b -n 11 -gpu" 2>/dev/null &



                ##Freesurfer recons only (including openmp flag)
		#konsole --noclose --profile Shell --new-tab -p tabtitle="$PARTIC" -e bash -c "source ~/.bashrc; FEED_openDTI.sh $Study -p $PARTIC -f -rawT "$ANAT_dir" -n 11" 2>/dev/null &



		##Commence after preprocessing (assumes preprocessing has already been run
		#konsole --noclose --profile Shell --new-tab -p tabtitle="$PARTIC" -e bash -c "source ~/.bashrc; FEED_openDTI.sh $Study -p $PARTIC -b -T -reinit -stats -n 11 -gpu" 2>/dev/null &

		##Pull stats only
                konsole --noclose --profile Shell --new-tab -p tabtitle="$PARTIC" -e bash -c "source ~/.bashrc; FEED_openDTI.sh $Study -p $PARTIC -reinit -stats" 2>/dev/null &

	else
		if [ -z $DWI_dir ]; then
			echo -e "\n\n\nMissing DWI directory for "$PARTIC". Check that sequence directory exists or restructure 'find' command to capture the directory name. Skipping "$PARTIC"..."
			echo "$PARTIC" >> $Study/skipped_participants.txt
			echo -e "Skipping "$PARTIC"...\n\n\n"
			continue
		fi
		if [ -z $P2A_dir ]; then
			echo -e "\n\n\nMissing P2A directory for "$PARTIC". Check that sequence directory exists or restructure 'find' command to capture the directory name. Skipping "$PARTIC"..."
			echo "$PARTIC" >> $Study/skipped_participants.txt
			echo "Skipping "$PARTIC"...\n\n\n"
			continue
		fi
		if [ -z $ANAT_dir ]; then
			echo -e "\n\n\nMissing T1 ANATOMICAL directory for "$PARTIC". Check that sequence directory exists or restructure 'find' command to capture the directory name."
			echo "Skipping "$PARTIC"...\n\n\n"
			echo "$PARTIC" >> $Study/skipped_participants.txt
			continue
		fi
	fi

	sleep 10

echo -e "\n\n\nSpawned konsole window with pipeline for "$PARTIC"..."
echo "-------------------------------------------------------------------------------"
done

echo -e "\n\n\nFinished submitting batch runs. It is recommended that you continually monitor job progress across the konsole tabs, aborting all if necessary. Also, keep an eye on node resource-usage using top or htop, and job queueing if you are working on a cluster with a batch queuing system.\n\n\n"

sleep 10

if [[ $parallel_conf == 1 ]]; then
	##Monitor resources across nodes in cluster
	host_list=`qhost | awk '{ print $1 }' | grep -v "HOSTNAME" | grep -v "global" | tr -d - | grep -v '^$'`
	while [ 1 ]; do
		for host in `echo $host_list`; do
			ssh "$host" -t '{ timeout 10 htop; } & htop ' || break
		done
		timeout 10 watch qstat
	done
fi
