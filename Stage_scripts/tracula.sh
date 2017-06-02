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
reinit_check=${10}
view_outs=${11}    
debug=${12}

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

#########TRACULA##########

batch_mode=1 ##1 is on, 0 is off

##Set preprocessed image input depending on whether denoising options were used
if [ -f ""$output_dir"/"$PARTIC"/iso_eddy_corrected_data_nodenoised.nii.gz" ]; then
    preprocessed_img='iso_eddy_corrected_data_nodenoised.nii.gz'
    bet_img='iso_bet_mask.nii.gz'
elif [ -f ""$output_dir"/"$PARTIC"/iso_eddy_corrected_data_denoised.nii.gz" ]; then
    preprocessed_img='iso_eddy_corrected_data_denoised.nii.gz'
    bet_img='iso_bet_mask.nii.gz'
elif [ -f ""$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz" ]; then
    preprocessed_img='eddy_corrected_data_denoised.nii.gz'
    bet_img='bet_mask.nii.gz'
elif [ -f ""$output_dir"/"$PARTIC"/eddy_corrected_data_nodenoised.nii.gz" ]; then
    preprocessed_img='eddy_corrected_data_nodenoised.nii.gz'
    bet_img='bet_mask.nii.gz'
else
    echo -e "\n\n\nPreprocessed image not found. Check "$output_dir"/"$PARTIC" to be sure either eddy_corrected_data_denoised.nii.gz or eddy_corrected_data_nodenoised.nii.gz actually exist. These may include an "iso_" prefix if you resliced. If not, re-run preprocessing."
    exit 0
fi

if [[ $tracula == 1 ]]; then
    echo -e "USING "$preprocessed_img"...\n"
    ##Check if TRACULA has already been run
    if [ -f "$tracdir"/tractography_output/"$PARTIC"/dpath/merged_avg33_mni_bbr.mgz ]; then
        echo -e "\n\n\nWARNING! Merged tracts file already found for this participant\n\n\n"
    fi

    rm -rf "$Study"/"$tracdir"/tractography_output/"$PARTIC"

    ##Make all TRACULA folders
    if [ ! -d "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri ]; then
        mkdir -p "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri
    fi
    if [ ! -d "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX ]; then
        mkdir -p "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX
    fi
    if [ ! -d "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dlabel/"diff" ]; then
        mkdir -p "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dlabel/"diff"
    fi

    ##copy bedpostx files
    cp -a "$output_dir"/"$PARTIC"/bedpostx_""$PARTIC"".bedpostX/* "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri.bedpostX 2>/dev/null

    ##copy and rename dmri base files
    cp "$output_dir"/"$PARTIC"/"$preprocessed_img" "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri 2>/dev/null
    mv "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/"$preprocessed_img" "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/dwi.nii.gz 2>/dev/null

    ##Ensure correct orientation
    #fslorient -swaporient "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/dwi.nii.gz
    #fslorient -swaporient "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/dwi.nii.gz

    ##copy and rename bvec and bval
    cp "$output_dir"/"$PARTIC"/bvec "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri 2>/dev/null
    mv "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/bvec "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/bvecs 2>/dev/null

    cp "$output_dir"/"$PARTIC"/bval "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri 2>/dev/null
    mv "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/bval "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/bvals 2>/dev/null

    ##copy and rename all necessary brain mask inputs
    cp "$output_dir"/"$PARTIC"/"$bet_img" "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri 2>/dev/null
    mv "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/"$bet_img" "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/nodif_brain_mask.nii.gz 2>/dev/null
    cp "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/nodif_brain_mask.nii.gz "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dlabel/"diff" 2>/dev/null
    mv "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dlabel/"diff"/nodif_brain_mask.nii.gz "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dlabel/"diff"/lowb_brain_mask.nii.gz 2>/dev/null
    cp "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/nodif_brain_mask.nii.gz "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/nodif_brain_mask.nii.gz 2>/dev/null
    mv "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/nodif_brain_mask.nii.gz "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/lowb.nii.gz 2>/dev/null

    ##copy and rename DTIFIT output to dmri
    if [ ! -f "$output_dir"/"$PARTIC"/dtifit_FA.nii.gz ]; then
        cd "$output_dir"/"$PARTIC"/
        for i in `find . -type f -name ""$PARTIC"*" -not -iname "*.nrrd" -maxdepth 1`; do
            mv -v $i ${i/""$PARTIC""/dtifit};
        done
    fi

    ##copy DTIFIT output to dmri
    cp -a "$output_dir"/"$PARTIC"/dtifit_* "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri 2>/dev/null
    wait

    ##Ensure freesurfer recon is complete before continuing to TRACULA
    echo -e "\n\n\nCHECKING FOR FREESURFER RECON COMPLETION...\n\n\n"

    trap "exit" INT
    until grep -q "finished without error" ""$Study"/"$tracdir"/diffusion_recons/"$PARTIC"/scripts/recon-all.log"; do
        sleep 5
        echo -e "\n\n\nWaiting for completed FREESURFER recon before resuming with TRACULA...\n\n\n"
    done

    echo -e "\n\n\nCREATING TRACULA CONFIGURATION FILE...\n\n\n"

    ##Delete Config File if already existing
    if [ -f ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt" ]; then
        rm -f ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt" 2>/dev/null
    fi
    ##Create config file
    echo -e '#!/bin/tcsh\nset workingDIR = "'"$Study"'/'"$tracdir"'"\nset SUBJECTS_DIR = $workingDIR/diffusion_recons\nsetenv SUBJECTS_DIR $workingDIR/diffusion_recons\nset dtroot =  $workingDIR/tractography_output\nset subjlist = ( '"$PARTIC"' )\nset dcmroot = '"$Study"'/'"$output_dir"'\nset dcmlist = ( $dcmroot/'"$PARTIC"'/dmri/dwi.nii.gz )\nset bvecfile = ( '"$Study"'/'"$tracdir"'/tractography_output/'"$PARTIC"'/dmri/bvecs )\nset bvalfile = '"$Study"'/'"$tracdir"'/tractography_output/'"$PARTIC"'/dmri/bvals \nset ncpts = (6 6 5 5 5 5 7 5 5 5 5 5 4 4 5 5 5 5) \nsource $FREESURFER_HOME/SetUpFreeSurfer.csh' >> ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt"

    echo -e "\n\n\nRUNNING TRACULA...\n\n\n"

    if [[ $batch_mode == 0 ]]; then
	##Intrasubject Reg
	echo -e "Running Intrasubject Registration\n\n\n"
	trac-all -no-isrunning -intra -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt
	wait

	##Intersubject Reg
	echo -e "Running Intersubject Registration\n\n\n"
	trac-all -no-isrunning -inter -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt

	##Masks Prep
	echo -e "Running Mask Prep\n\n\n"
	trac-all -no-isrunning -masks -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt
	wait

	##Priors Prep 
	echo -e "Running Priors\n\n\n"
	trac-all -no-isrunning -prior -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt
	wait 

	##Reconstruct Paths
	echo -e "Running Path Reconstruction\n\n\n"
	trac-all -no-isrunning -path -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt
	wait

    elif [[ $batch_mode == 1 ]]; then
	##Intrasubject Reg
	echo -e "Creating Intrasubject Registration Job File\n\n\n"
	trac-all -no-isrunning -intra -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt -jobs "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_intra.txt 

	##Intersubject Reg
	echo -e "Creating Intersubject Registration Job File\n\n\n"
	trac-all -no-isrunning -inter -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt -jobs "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_inter.txt

	##Masks Prep
	echo -e "Creating Mask Prep Job File\n\n\n"
	trac-all -no-isrunning -masks -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt -jobs "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_masks.txt

	##Priors Prep 
	echo -e "Creating Priors Job File\n\n\n"
	trac-all -no-isrunning -prior -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt -jobs "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_prior.txt

	##Reconstruct Paths
	echo -e "Creating Path Reconstruction Job File\n\n\n"
	trac-all -no-isrunning -path -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config.txt -jobs "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_paths.txt

	trac_A=`fsl_sub -s mpi -N trac_A_"$PARTIC" -T 800 -t "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_intra.txt | grep -oP "Submitted batch job\s+\K\w+"`    
	trac_B=`fsl_sub -j "$trac_A" -s mpi -N trac_B_"$PARTIC" -T 800 -t "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_inter.txt | grep -oP "Submitted batch job\s+\K\w+"`
	trac_C=`fsl_sub -j "$trac_B" -s mpi -N trac_C_"$PARTIC" -T 1200 -t "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_masks.txt | grep -oP "Submitted batch job\s+\K\w+"`
	trac_D=`fsl_sub -j "$trac_C" -s mpi -N trac_D_"$PARTIC" -T 1200 -t "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_prior.txt | grep -oP "Submitted batch job\s+\K\w+"`
	fsl_sub -j "$trac_D" -s mpi -N trac_E_"$PARTIC" -T 1200 -t "$Study"/"$tracdir"/tractography_output/"$PARTIC"/batch_"$PARTIC"_paths.txt
	echo "Submitted TRACULA Dependency Tree!"
    fi

    until [ -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/scripts/"trac-paths.done" ]; do
        sleep 5
    done

    ##SGE/BEOWULF CLUSTER LEGACY SCRIPTS
    ##Run FSL's FAST to get CSF, Grey Matter, and White Matter masks. These can be used to confirm the accuracy of the tracula reconstructions
    ##Register anatomical to diffusion .bbr.nii.gz (i.e. "TRACULA") diffusion space
    #flirt -in $Study/$tracdir/tractography_output/$PARTIC/dmri/brain_anat.nii.gz -ref $Study/$tracdir/tractography_output/$PARTIC/dlabel/'diff'/aparc+aseg.bbr.nii.gz -out $Study/$tracdir/tractography_output/$PARTIC/dmri/brain_anat_FAST.nii.gz -omat $Study/$tracdir/tractography_output/$PARTIC/dmri/brain_anat_flirt.mat -bins 256 -cost normmi -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp trilinear

    ##Run Segmentation to extract Grey, White, and CSF Masks
    #fast -t 1 -o $Study/$tracdir/tractography_output/$PARTIC/FAST $Study/$tracdir/tractography_output/$PARTIC/dmri/brain_anat_FAST.nii.gz

    ##Rename FAST outputs to Grey, White, and CSF
    #mv $Study/$tracdir/tractography_output/$PARTIC/FAST_pve_0.nii.gz $Study/$tracdir/tractography_output/$PARTIC/CSF.brr.nii.gz
    #mv $Study/$tracdir/tractography_output/$PARTIC/FAST_pve_1.nii.gz $Study/$tracdir/tractography_output/$PARTIC/white.brr.nii.gz
    #mv $Study/$tracdir/tractography_output/$PARTIC/FAST_pve_2.nii.gz $Study/$tracdir/tractography_output/$PARTIC/grey.brr.nii.gz
fi

if [[ $reinit_check == 1 ]]; then
    echo -e "\n\n\nCHECKING FOR INCOMPLETE/MISSING TRACTS...\n\n\n"
    
    ##Source Freesurfer Home
    export SUBJECTS_DIR=""$Study"/"$tracdir"/diffusion_recons"

    trap "exit" INT
    for i in `ls "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath | grep -v "merged"`; do    
        voxel_num=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/"$i"/pathstats.byvoxel.txt | wc -l`
        echo "voxel_num for $i is $voxel_num"
        
        ##Get tract name for config file
        j=`echo "$i" | sed 's/_avg33_mni_bbr*//'`
        
        if [ "$voxel_num" -le 40 ] && [ "$voxel_num" -gt "0" ]; then
            echo -e "\nTract "$i" is only "$voxel_num" voxels in size. Reinitializing pathway...\n\n\n"
        
            ##Delete Config File if already existing
            if [ -f ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt" ]; then
                rm -f ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt" 2>/dev/null
            fi
        
            ##Create config file
            echo -e '#!/bin/tcsh\nset workingDIR = "'"$Study"'/'"$tracdir"'"\nset SUBJECTS_DIR = $workingDIR/diffusion_recons\nsetenv SUBJECTS_DIR $workingDIR/diffusion_recons\nset dtroot =  $workingDIR/tractography_output\nset subjlist = ( '"$PARTIC"' )\nset dcmroot = '$SUBJECTS_DIR'\nset dcmlist = ( $dcmroot/'"$PARTIC"'/dmri/dwi.nii.gz )\nset bvecfile = ( '"$Study"'/'"$tracdir"'/tractography_output/'"$PARTIC"'/dmri/bvecs )\nset bvalfile = '"$Study"'/'"$tracdir"'/tractography_output/'"$PARTIC"'/dmri/bvals \nset pathlist = ( "$j" ) \nset ncpts = ( 7 ) \nset reinit = 1 \nsetenv FREESURFER_HOME /usr/local/freesurfer\nsource $FREESURFER_HOME/SetUpFreeSurfer.csh' > ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt"

            ##Priors Prep 
            echo -e "Re-running Priors for "$i"\n"
            trac-all -no-isrunning -prior -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt
	    wait

            ##Reconstruct Paths
            echo -e "Re-running Path Reconstruction for "$i"\n"
            trac-all -no-isrunning -path -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt
	    wait

            ##Re-check for incompleteness or missingness
            voxel_num_reinit=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/"$i"/pathstats.byvoxel.txt | wc -l`
            if [ "$voxel_num_reinit" -le 40 ]; then
                echo "$i" >> "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/UNUSUABLE_TRACTS.txt    
                echo -e "\n\n\nWARNING! tract "$i" is still likely incomplete or missing. It is recommended that you inspect this tract visually in freeview, altering the default threshold as necessary. Statistics derived from tract "$i" may not be useable for subject "$PARTIC". See "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/UNUSUABLE_TRACTS.txt for the log of this and any other problematic tract reconstructions\n\n\n" 
                continue
            fi
        else
            continue
        fi
    done
    
    ##Check for voxel assymetry across hemispheres and reinit the tract that is low in voxels
    for i in `ls "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath | grep -v "merged"`; do
        voxel_num=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/"$i"/pathstats.byvoxel.txt | wc -l`

        ##Get tract name for config file
        j=`echo "$i" | sed 's/_avg33_mni_bbr*//'`

        k=`echo "$j" | sed 's/_avg33_mni_bbr*//' | grep -v "fmajor" | grep -v "fminor" | sed 's/.*\.//'`
    
        ##Skip iteration with blank lines
        if [ -z "$k" ]; then
            continue    
        fi
        
        ##Create a system of hemispheric voxel comparison called "Jack" and "Jill"    
        jack=lh."$k"
        jill=rh."$k"
    
        voxel_num_jack=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/"$jack"_avg33_mni_bbr/pathstats.byvoxel.txt | wc -l`
        voxel_num_jill=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/"$jill"_avg33_mni_bbr/pathstats.byvoxel.txt | wc -l`

        echo -e "\n\n\n$jack has "$voxel_num_jack" voxels"
        echo -e "$jill has "$voxel_num_jill" voxels\n\n\n"
    
        diff=`expr $voxel_num_jack - $voxel_num_jill | tr -d -`

        echo "Difference between the left "$k" reconstruction and the right "$k" reconstruction is "$diff" voxels..."
        if [ "$diff" -gt "40" ]; then
            if [ "$voxel_num_jack" -lt "$voxel_num_jill" ]; then
                z="$jack"
            elif [ "$voxel_num_jill" -lt "$voxel_num_jack" ]; then
                z="$jill"
            fi
            echo -e "\n\n\nTracts "$jack" and "$jill" differ in size by a large number of voxels. Unless this data is from an individual with possible white matter damage, "$z" likely failed reconstruction (i.e. is missing or incomplete). Attempting to reinitialize "$z" using a different initial starting guess...\n\n\n"

	    ##Delete Config File if already existing
	    if [ -f ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt" ]; then
		    rm -f ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt" 2>/dev/null
	    fi

	    ##Create config file
	    echo -e '#!/bin/tcsh\nset workingDIR = "'"$Study"'/'"$tracdir"'"\nset SUBJECTS_DIR = $workingDIR/diffusion_recons\nsetenv SUBJECTS_DIR $workingDIR/diffusion_recons\nset dtroot =  $workingDIR/tractography_output\nset subjlist = ( '"$PARTIC"' )\nset dcmroot = '$SUBJECTS_DIR'\nset dcmlist = ( $dcmroot/'"$PARTIC"'/dmri/dwi.nii.gz )\nset bvecfile = ( '"$Study"'/'"$tracdir"'/tractography_output/'"$PARTIC"'/dmri/bvecs )\nset bvalfile = '"$Study"'/'"$tracdir"'/tractography_output/'"$PARTIC"'/dmri/bvals \nset pathlist = ( '"$z"' ) \nset ncpts = ( 7 ) \nset reinit = 1 \nsetenv FREESURFER_HOME /usr/local/freesurfer\nsource $FREESURFER_HOME/SetUpFreeSurfer.csh' > ""$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt"

	    ##Priors Prep
	    echo -e "Re-running Priors for "$i"\n"
	    trac-all -no-isrunning -prior -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt
            wait

	    ##Reconstruct Paths
	    echo -e "Re-running Path Reconstruction for "$i"\n"
	    trac-all -no-isrunning -path -c "$Study"/"$tracdir"/tractography_output/"$PARTIC"/trac_config_reinit.txt
            wait

            ##Re-assess difference in voxels
            voxel_num_jack=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/"$jack"_avg33_mni_bbr/pathstats.byvoxel.txt | wc -l`
                    voxel_num_jill=`cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/"$jill"_avg33_mni_bbr/pathstats.byvoxel.txt | wc -l`

            echo "voxel num for $jack is now $voxel_num_jack"
            echo "voxel num for $jill is now $voxel_num_jill"

            diff_reinit=`expr $voxel_num_jack - $voxel_num_jill | tr -d -`
            
            if [ "$diff_reinit" -gt "30" ]; then
                echo "$z" >> "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/UNUSUABLE_TRACTS.txt 
                echo -e "\n\n\nWARNING! tracts "$jack" and "$jill" still differ in size by a large number of voxels. It is recommended that you inspect these tract visually in freeview, altering the default thresholds as necessary. Statistics derived from tract "$z" may not be useable for subject "$PARTIC". See "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/UNUSUABLE_TRACTS.txt for the log of this and any other problematic tract reconstructions\n\n\n"
                continue
            fi
        else
            continue
        fi
    done
    touch "$Study"/"$tracdir"/tractography_output/"$PARTIC"/reinit_complete.txt
fi

##View tracula output
if [ -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/merged_avg33_mni_bbr.mgz ] && [ "$tracdir"/tractography_output/"$PARTIC"/dmri/dtifit_FA.nii.gz ] && [[ $view_outs == 1 ]]; then
    freeview -tv "$tracdir"/tractography_output/"$PARTIC"/dpath/merged_avg33_mni_bbr.mgz "$tracdir"/tractography_output/"$PARTIC"/dmri/dtifit_FA.nii.gz &
fi

echo "TRACULA DONE!"
exit 0
