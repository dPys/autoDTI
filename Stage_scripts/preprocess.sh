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
dwi_dir=${1} ##Source directory for DWI raw dicoms
P2A=${2} ##Source directory for P2A B0 raw dicoms
output_dir=${3} ##Directory where preprocessing is conducted. Unless manually altered, this should be called "dti_preproc"
OddSlices=${4} ##Value equal to 1 or 2 specifying which slice (bottom or top) should be removed from data during TOPUP/new EDDY in cases of odd slices
PARTIC=${5} ##Participant ID used to label folders and files
sequence=${6} ##Number corresponding to a sequence acceleration factor (e.g. multiband 2 or 3) or any arbitrary number you wish to distinguish analysis runs when using data from differing sequence types
T1directory=${7} ##Source directory for T1 MPRAGE raw dicoms
Study=${8} ##A base folder (must actually exist) where autoDTI will run its operations
preproc=${9} ##Binary switch variable to indicate whether or not preprocessing will be run
tracula=${10} ##Binary switch variable to indicate whether or not tracula will be run
buildsurf=${11} ##Binary switch variable to indicate whether or not surface reconstruction will be run
probtracking=${12} ##Binary switch variable to indicate whether or not connectome mapping will be run
eddy_type=${13} ##Binary switch variable to indicate whether old eddy_correct or new eddy with TOPUP will be run
bpx=${14} ##Binary switch variable to indicate whether or not bedpostx will be run
parcellate=${15} ##Binary switch variable to indicate whether or not FREESURFER reconstruction will be run
stats=${16} ##Binary switch variable to indicate whether or not key metrics from tracula and freesurfer output will be extracted to a .csv file
NumCores=${17} ##Number of cores to be used in the pipeline run. *Note: If the -n flag is used, however, it will override the default specified in FEED_autoDTI.sh configuration options section.
E_switch=${18} ##Binary switch variable to indicate whether or not to run new Eddy after -avr check has been performed with old eddy_correct
NRRD=${19} ##Binary switch variable to indicate whether or not .NRRD conversion will be run
parallel_type=${20}  ##variable indicating the job scheduler type used if batch queueing system is installed. This is defined in FEED_autoDTI.sh configuration options section.
QA=${21} ##Binary switch variable to indicate whether or not FREESURFER's Quality Assessment tool will be run
NumCoresMP=${22} ##Number of LOCAL cores to be used in the pipeline run. This is detected automatically in FEED_autoDTI.sh
denoising=${23} ##Denoising type
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
debug=${48} ##Run scripts with full verbosity
ALLOCATION=${49} ##Allocation name for fsl_sub
reslice=${50} ##Switch to relice to isotropic voxels
TOTAL_READOUT=${51} ##Total readout value (for topup/eddy)

#####PREPROCESSING--ADVANCED CONFIGURATION OPTIONS######
frac_thresh="0.2" ##for BET fractional intensity thresholds
fugue_smooth="4" ##Set fugue smoothing level for fieldmap correction
########################################################

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

start_timestamp=$(date +%s)

##Navigate to Participant's directory
cd "$output_dir"/"$PARTIC"

##Check E_switch
if [[ $E_switch == 1 ]]; then
    eddy_type=0
fi

##Run dcm to nii conversion and eddy correction
if [[ $noconv != 1 ]]; then
    ##Convert to NIFTI
    echo -e "\n\n\nCONVERTING TO COMPRESSED NIFTI USING $conversion_type..."
    if [[ $conversion_type == "dcm2niix" ]]; then
        dcm2niix -z y "$dwi_dir"
	wait

        ##Rename converted nifti file
        mv -v "$dwi_dir"/*.nii.gz "$output_dir"/"$PARTIC"/original_data.nii.gz 2>/dev/null
        mv -v "$dwi_dir"/*.bvec "$output_dir"/"$PARTIC"/bvec 2>/dev/null
        mv -v "$dwi_dir"/*.bval "$output_dir"/"$PARTIC"/bval 2>/dev/null
	wait

        echo -e "\n\n\nRENAMING CONVERTED NIFTI FILE AND BVEC/BVAL FILES AND COPYING INTO $output_dir...\n\n\n"

    elif [[ $conversion_type == "mriconvert" ]]; then
        mcverter "$dwi_dir" -o "$dwi_dir" -f fsl -d -n -q
	wait
        ls "$dwi_dir"/*.nii | tail -1 | xargs gzip -f
	wait

        ##Rename converted nifti file
        mv -v "$dwi_dir"/*.nii.gz "$output_dir"/"$PARTIC"/original_data.nii.gz 2>/dev/null
        mv -v "$dwi_dir"/*bvecs "$output_dir"/"$PARTIC"/bvec 2>/dev/null
        mv -v "$dwi_dir"/*bvals "$output_dir"/"$PARTIC"/bval 2>/dev/null
	wait

        echo -e "\n\n\nRENAMING CONVERTED NIFTI FILE AND BVEC/BVAL FILES AND COPYING INTO $output_dir...\n\n\n"
    fi
    if [[ $fieldmap == 1 ]]; then
        ##Convert Magnitude file to .nii
        if [[ $conversion_type == "dcm2niix" ]]; then
            dcm2niix -z y "$mag_dir"
            wait
        elif [[ $conversion_type == "mriconvert" ]]; then
            mcverter "$mag_dir" -o "$mag_dir" -f fsl -d -n -q
        wait
            ls "$mag_dir"/*.nii | tail -1 | xargs gzip -f
            wait
        fi

        ##Convert Phase file to .nii
        if [[ $conversion_type == "dcm2niix" ]]; then
            dcm2niix -z y "$phase_dir"
            wait
        elif [[ $conversion_type == "mriconvert" ]]; then
            mcverter "$phase_dir" -o "$phase_dir" -f fsl -d -n -q
            ls "$phase_dir"/*.nii | tail -1 | xargs gzip -f
            wait
        fi

        ##Rename converted nifti files and copy to output_dir
        mag_file=`find "$mag_dir" -iname '*.nii.gz' -print | head -1`
        mv -v "$mag_file" "$output_dir"/"$PARTIC"/FieldMap_Magnitude.nii.gz
        wait

        phase_file=`find "$phase_dir" -iname '*.nii.gz' -print | head -1`
        mv -v "$phase_file" "$output_dir"/"$PARTIC"/FieldMap_Phase.nii.gz
        wait
    fi
    if [[ $eddy_type == 1 ]]; then
        ##Convert P2A to nifti
        if [[ $conversion_type == "dcm2niix" ]]; then
            dcm2niix -z y "$P2A"
            wait
        elif [[ $conversion_type == "mriconvert" ]]; then
            mcverter "$P2A" -o "$P2A" -f fsl -d -n -q
            wait
            ls "$P2A"/*.nii | tail -1 | xargs gzip -f
            wait
        fi
        wait
    fi
fi

if [[ $volrem != 'Null' ]]; then
    ##Split 4d file to 3d directional volumes
    fslsplit original_data original_data_3d -t
    wait

    ##Transpose bvecs rows to columns
    ##Read in the bvecs file
    BVECFILE=bvec
    BVECNEWFILE=bvec_trans
    ##Store it as an array
    c=0; while read line; do BVEC[c]=`echo "$line"`; let c=$c+1; done < "$BVECFILE"
    BVECNUM=${#BVEC[@]}
    ##Check the number of directions
    GRADNUM=$(echo "$BVEC" | wc -w )
    ##Indexing at i=1 so we get rid of the first vol0 indexed as 0
    if [ -f "$BVECNEWFILE" ]; then
        echo -e "\n\n\n"$BVECNEWFILE" already exists. Numbering new versions...\n\n\n" >> bvec_change_log.txt
        rm -f "$BVECNEWFILE"
    fi
    echo -e "\n\n\nTRANSPOSED BVECS IS SAVED AS "$BVECNEWFILE"\n\n\n"
    for ((i=1; i<=${GRADNUM}; i++ )); do
        gx=$(echo ${BVEC[0]} | awk -v x=$i '{print $x}')
        gy=$(echo ${BVEC[1]} | awk -v x=$i '{print $x}')
        gz=$(echo ${BVEC[2]} | awk -v x=$i '{print $x}')
        echo "$gx $gy $gz" >> "$BVECNEWFILE"
    done

    ##Create an array of all volumes specified for removal
    declare -a volrem=($volrem)
    ##Loop through that array and remove each corresponding 3d volume, revising bval and bvec upon each iteration
    for i in `echo ${volrem[@]}`; do
        rm -f "original_data_3d00$i.nii.gz"
        echo  "Removing volume $i from dataset..."
        sed -e "$i"d bvec_trans > tmp_bvec && mv tmp_bvec bvec_trans
        wait
        awk '{$'$i'=""; print $0}' bval | sed 's/  */ /g' > tmp_bval && mv tmp_bval bval
        wait
        echo "Updating bvec and bval files..."
    done

    ##Transpose bvec back to horizontal x,y,z
    awk '
    {
        for (i=1; i<=NF; i++)  {
            a[NR,i] = $i
        }
    }
    NF>p { p = NF }
    END {
        for(j=1; j<=p; j++) {
            str=a[1,j]
            for(i=2; i<=NR; i++){
                str=str" "a[i,j];
            }
            print str
        }
    }' bvec_trans > bvec

    ##Merge the individual 3d volumes back together
    fslmerge -t original_data original_data_3d*
    wait

    ##Clean up temp 3d volume set
    rm -f original_data_3d*
fi

##If bvec_change_log does not exist, create it.
if [ ! -f "$output_dir"/"$PARTIC"/bvec_change_log.txt ]; then
    touch bvec_change_log.txt
fi

##Learn about gradient values for sequence
rm -f "$output_dir"/"$PARTIC"/b0_indices_trans 2>/dev/null
rm -f "$output_dir"/"$PARTIC"/numb0s.txt 2>/dev/null
bval=`find "$output_dir"/"$PARTIC" -iname "bval" -print | head -1`
if [ -z "$bval" ]; then
    echo "ERROR: no bval file found. Retry running pipeline from scratch."
    exit 0
fi
B0_tmp_count=`grep -Ei '[[:space:]]+0' -o "$bval" | wc -l`
if [[ $B0_tmp_count==0 ]]; then
    B0_tmp_count=`grep -Ei '[[:space:]]+5' -o "$bval" | wc -l`
    echo -e "\n\n\nWarning! Double-check bval file. No 0's detected...\n\n\n"
fi
expr $B0_tmp_count + 1 | echo $(xargs) > numb0s.txt
b0s_TOTAL=`cat numb0s.txt`
VOLS_TOTAL=`fslnvols original_data.nii.gz`
DIRS_TOTAL=`echo $(echo $VOLS_TOTAL - $b0s_TOTAL | bc)`

##Identify placement index of b0's and echo to b0_indices file (NOTE: this is NOT the same as the index file fed into EDDY)
echo -e "\n\n\nINTERPRETING B0 PLACEMENT...\n\n\n"
array=`awk '{ $(NF+1) = ""; print }' bval`
my_array=($array)
value1=0
value2=5
for i in ${!my_array[@]}; do
    if [[ ${my_array[$i]} = ${value1} || ${my_array[$i]} = ${value2} ]]; then
        echo -e ${i} >> b0_indices_trans;
    fi
done

curr_timestamp=$(date +%s)
elapsed_time=$(expr $curr_timestamp - $start_timestamp)
echo -e "Elapsed (Configure routine): "$elapsed_time"\n" >> "$output_dir"/"$PARTIC"/elapsed_time.log

if [[ $after_eddy != 1 ]]; then
    if [[ $eddy_type == 2 ]]; then
        echo -e "Total readout is $TOTAL_READOUT\n\n\n"

        ##Create parameters file to feed to TOPUP and EDDY. Remove any existing first.
        if [ -f parameters.txt ]; then
            rm -f parameters.txt 2>/dev/null
        fi
        for i in $(seq 1 "$b0s_TOTAL"); do
            printf "0 -1 0 "$TOTAL_READOUT"\n" >> parameters.txt
        done

        ##Create index file based on directions
        indx=""
        for ((i=1; i<="$VOLS_TOTAL"; i+=1)); do indx="$indx 1"; done
        echo "$indx" > index1.txt

	##Extract and Combine all B0s collected for TOPUP
        for b0_index in $(< b0_indices_trans); do
            fslroi original_data.nii.gz b0_A2P_"$b0_index" "$b0_index" 1
            wait
        done

	##Merge all B0's: A>>P and P>>A
        echo -e "\n\n\nMERGING A>>P B0's AND P>>A B0's IN PREPARATION FOR TOPUP...\n\n\n"
        fslmerge -t both_b0 b0_A2P_* 2>/dev/null
	wait

        rm -f b0_A2P_* 2>/dev/null

	##Brain extract that average B0 using BET
        bet both_b0 hifi_b0_brain -f $frac_thresh -m
	wait

        ##Run Eddy
        echo -e "\n\n\nRUNNING EDDY CORRECTION...\n\n\n"

        if [[ $parallel_type == 'SGE' ]] || [[ $parallel_type == 'PBS' ]] || [[ $parallel_type == 'SLURM' ]]; then
	          export OMP_NUM_THREADS="$NumCoresMP"
            eddy_openmp --imain=original_data.nii.gz --mask=hifi_b0_brain_mask.nii.gz --acqp=parameters.txt --index=index1.txt --bvecs=bvec --bvals=bval --out=eddy_corrected_data.nii.gz
	          wait
        elif [[ $parallel_type == 'none' ]] || [[ $parallel_type == 'Null' ]]; then
            eddy --imain=original_data.nii.gz --mask=hifi_b0_brain_mask.nii.gz --acqp=parameters.txt --index=index1.txt --bvecs=bvec --bvals=bval --out=eddy_corrected_data.nii.gz
	          wait
    	fi
        echo -e "\n\n\nEDDY CORRECTION COMPLETED\n\n\n"
        curr_timestamp=$(date +%s)
        elapsed_time=$(expr $curr_timestamp - $start_timestamp)
        echo -e "Elapsed (Eddy): "$elapsed_time" \n" >> "$output_dir"/"$PARTIC"/elapsed_time.log
    fi

    if [[ $eddy_type == 1 ]]; then
        ##Navigate to P2A raw data directory for the participant
        mv -v "$P2A"/*.nii.gz "$output_dir"/"$PARTIC"/P2A.nii.gz 2>/dev/null
	wait
        echo -e "\n\n\nRENAMING CONVERTED P2A B0 NIFTI FILE AND COPYING INTO $output_dir IN PREPARATION FOR TOPUP/EDDY...\n\n\n"

        P2Anumb0s=`fslnvols "$output_dir"/"$PARTIC"/P2A.nii.gz`
        echo -e "\n\n\nSEQUENCE HAS $b0s_TOTAL A>>P B0 VOLUMES AND $P2Anumb0s P>>A B0 VOLUMES...\n\n\n"
        echo -e "\n\n\nCONFIGURING PREPROCESSING ROUTINE FOR $DIRS_TOTAL directions and $VOLS_TOTAL VOLUMES IN TOTAL INCLUDING B0s...\n\n\n"

        dim1=`fslval "$output_dir"/"$PARTIC"/original_data.nii.gz dim1`
        dim2=`fslval "$output_dir"/"$PARTIC"/original_data.nii.gz dim2`
        dim3=`fslval "$output_dir"/"$PARTIC"/original_data.nii.gz dim3`
        dim4=`fslval "$output_dir"/"$PARTIC"/original_data.nii.gz dim4`
        P2Avols=`fslval "$output_dir"/"$PARTIC"/P2A.nii.gz dim4`

        ##Check for odd number of slices
        rem=$(( $dim3 % 2 ))

        ##If odd # of slices, remove either top or bottom volume
        if [[ $rem != 0 ]]; then
            new_slices=$(echo "($dim3 - 1)" | bc)
            if [[ $OddSlices == 1 ]]; then
                fslroi original_data.nii.gz original_data.nii.gz 0 $dim1 0 $dim2 0 $new_slices 0 $dim4
                wait

                fslroi P2A.nii.gz P2A.nii.gz 0 $dim1 0 $dim2 0 $new_slices 0 $P2Avols
                wait

            elif [[ $OddSlices == 2 ]]; then
                fslroi original_data.nii.gz original_data.nii.gz 0 $dim1 0 $dim2 1 $new_slices 0 $dim4
                wait

                fslroi P2A.nii.gz P2A.nii.gz 0 $dim1 0 $dim2 0 $new_slices 0 $P2Avols
                wait
            fi
        fi

        echo -e "Total readout is $TOTAL_READOUT\n\n\n"

        ##Create parameters file to feed to TOPUP and EDDY. Remove any existing first.
        if [ -f parameters.txt ]; then
            rm -f parameters.txt 2>/dev/null
        fi
        for i in $(seq 1 "$b0s_TOTAL"); do
            printf "0 -1 0 "$TOTAL_READOUT"\n" >> parameters.txt
        done

        ##Create index file based on directions and B0 placement
        VOLS_TOTAL_tmp=`echo $(echo $VOLS_TOTAL - 1 | bc)`
	indx=""
        b0s_list=`echo "$(< b0_indices_trans)"`
        k=1
        j=1
        for ((i=1; i<="$VOLS_TOTAL_tmp"; i+=1)); do
            if [[ $k == 1 ]]; then
                #echo "B0"
                indx="$indx "1"";
            fi
            if [[ ${b0s_list[@]} =~ " $k " ]]; then
                j=$(( $j + 1 ))
                #echo "B0"
            fi
            indx="$indx "$j"";
            #echo $indx
            k=$(( $k + 1 ))
        done
        echo "$indx" | sed 's/^  *//g' > index1.txt

        ##Extract and Combine all B0s collected for TOPUP
        for b0_index in $(< b0_indices_trans); do
            fslroi original_data.nii.gz b0_A2P_"$b0_index" "$b0_index" 1
            wait
        done

        for i in $(seq 1 "$P2Anumb0s"); do
            printf "0 1 0 "$TOTAL_READOUT"\n" >> parameters.txt
        done

        ##Merge all B0's: A>>P and P>>A
        echo -e "\n\n\nMERGING A>>P B0's AND P>>A B0's IN PREPARATION FOR TOPUP...\n\n\n"
        fslmerge -t both_b0 b0_A2P_* P2A.nii.gz 2>/dev/null
	wait

        ##Merge P2A B0 with A2P B0 closest in time
        #echo -e "\n\n\nMERGING LAST A>>P B0 AND P>>A b0's IN PREPARATION FOR TOPUP...\n\n\n"
        #rec_B0=`ls b0_A2P_* | sort -k2 -th -n | tail -1`
        #fslmerge -t both_b0 "$rec_B0" P2A.nii.gz 2>/dev/null

        rm -f b0_A2P_* 2>/dev/null

        ##Run TOPUP Using Combined B0 File and specified acqparams file
        echo -e "\n\n\nRUNNING TOPUP...\n\n\n"
        topup --imain=both_b0 --datain=parameters.txt --config="$FSLDIR"/etc/flirtsch/b02b0.cnf --out=topup_results --iout=hifi_b0 -v
        wait
	echo -e "\n\n\nTOPUP COMPLETED\n\n\n"
        curr_timestamp=$(date +%s)
        elapsed_time=$(expr $curr_timestamp - $start_timestamp)
        echo -e "Elapsed (TOPUP): "$elapsed_time"\n" >> "$output_dir"/"$PARTIC"/elapsed_time.log

        ##Used hifi_B0 from TOPUP to create an average B0
        fslmaths hifi_b0 -Tmean hifi_b0
	wait

        ##Brain extract that average B0 using BET
        bet hifi_b0 hifi_b0_brain -f $frac_thresh -m
	wait

	##Run Eddy
        echo -e "\n\n\nRUNNING EDDY CORRECTION...\n\n\n"
        if [[ $parallel_type == 'SGE' ]] || [[ $parallel_type == 'PBS' ]] || [[ $parallel_type == 'SLURM' ]]; then
            export OMP_NUM_THREADS="$NumCoresMP"
            eddy_openmp --imain=original_data.nii.gz --mask=hifi_b0_brain_mask.nii.gz --acqp=parameters.txt --index=index1.txt --bvecs=bvec --bvals=bval --out=eddy_corrected_data.nii.gz
	    wait
        elif [[ $parallel_type == 'none' ]] || [[ $parallel_type == 'Null' ]]; then
            eddy --imain=original_data.nii.gz --mask=hifi_b0_brain_mask.nii.gz --acqp=parameters.txt --index=index1.txt --bvecs=bvec --bvals=bval --out=eddy_corrected_data.nii.gz
	    wait
        fi
      	echo -e "\n\n\nEDDY CORRECTION COMPLETED\n\n\n"
      	curr_timestamp=$(date +%s)
        elapsed_time=$(expr $curr_timestamp - $start_timestamp)
        echo -e "Elapsed (Eddy from TOPUP): "$elapsed_time"\n" >> "$output_dir"/"$PARTIC"/elapsed_time.log
    fi
    if [[ $eddy_type == 1 || $eddy_type == 2 ]]; then
        ##Check for motion outliers
        echo -e "CHECKING FOR MOTION OUTLIERS ...\n\n\n"
        ec_plot_NEW.sh eddy_corrected_data.nii.gz
	wait

        ##Rename eddy extended outputs, if they are generated with your eddy version/type
        mv eddy_corrected_data.nii.gz.eddy_movement_rms eddy_movement_rms.txt 2>/dev/null
        mv eddy_corrected_data.nii.gz.eddy_outlier_map eddy_outlier_map.txt 2>/dev/null
        mv eddy_corrected_data.nii.gz.eddy_outlier_n_stdev_map eddy_outlier_n_stdev_map.txt 2>/dev/null
        mv eddy_corrected_data.nii.gz.eddy_outlier_report eddy_outlier_report.txt 2>/dev/null
        mv eddy_corrected_data.nii.gz.eddy_parameters eddy_parameters.txt 2>/dev/null
        mv eddy_corrected_data.nii.gz.eddy_post_eddy_shell_alignment_parameters eddy_post_eddy_shell_alignment_parameters.txt 2>/dev/null
	wait

        ##Delete unecessary files
        rm -f "$output_dir"/"$PARTIC"/hifi_b0.nii.gz 2>/dev/null
        rm -f "$output_dir"/"$PARTIC"/hifi_b0_brain.nii.gz 2>/dev/null
        rm -f "$output_dir"/"$PARTIC"/b0_indices_trans 2>/dev/null
        rm -f "$output_dir"/"$PARTIC"/both_b0* 2>/dev/null
        rm -f "$output_dir"/"$PARTIC"/topup_results_* 2>/dev/null
        #rm -f "$output_dir"/"$PARTIC"/b0_A2P_* 2>/dev/null
        rm -f "$output_dir"/"$PARTIC"/numb0s.txt 2>/dev/null
        rm -f "$output_dir"/"$PARTIC"/index1.txt 2>/dev/null
    elif [[ $eddy_type == 0 ]]; then
        if [[ $E_switch == 1 ]]; then
            echo -e "\n\n\nFIRST MODELING MOVEMENT ACROSS VOLUMES USING AFFINE REGISTRATION. THIS SHOULD TAKE APPROXIMATELY 15-20 MINUTES...\n\n\n"
            ##Old Eddy Correction
            eddy_correct original_data.nii.gz eddy_corrected_data.nii.gz 0 2>/dev/null
            wait
        else
	    echo -e "\n\n\nRUNNING OLD EDDY CORRECTION...\n\n\n"
            ##Old Eddy Correction
            eddy_correct original_data.nii.gz eddy_corrected_data.nii.gz 0 2>/dev/null
	    wait
            echo -e "\n\n\nEDDY CORRECTION COMPLETED\n\n\n"
        fi

        ##Run BET on eddy output
        bet eddy_corrected_data.nii.gz bet.nii.gz -m -f $frac_thresh
	wait

        ##Check for motion outliers
        echo -e "\n\n\nCHECKING FOR MOTION OUTLIERS ...\n\n\n"
        ec_plot.sh eddy_corrected_data.ecclog
	wait
    fi
fi

if [[ $after_eddy == 1 ]]; then
    echo -e "\n\n\nSKIPPING EDDY CORRECTION...\n\n\n"
fi

if [ ! -f ""$output_dir"/"$PARTIC"/eddy_corrected_data.nii.gz" ]; then
    echo -e "\n\n\nWARNING! No eddy_corrected_data.nii.gz detected. Try running preprocessing again from scratch."
fi

##Automatically remove image volumes according to ec_plot output
if [[ $auto_volrem == 1 ]]; then
    echo -e "\n\n\nAUTOMATICALLY DETECTING AND REMOVING PROBLEM VOLUMES...\n\n\n"
    rm -f bad_vols.txt 2>/dev/null

    ##Transpose bvecs rows to columns
    ##Read in the bvecs file
    BVECFILE=bvec
    BVECNEWFILE=bvec_trans
    ##Store it as an array
    c=0; while read line; do BVEC[c]=`echo "$line"`; let c=$c+1; done < "$BVECFILE"
    BVECNUM=${#BVEC[@]}
    ##Check the number of directions
    GRADNUM=$(echo "$BVEC" | wc -w )
    ##Indexing at i=1 so we get rid of the first vol0 indexed as 0
    if [ -f "$BVECNEWFILE" ]; then
        echo -e "\n\n\n"$BVECNEWFILE" already exists. Numbering new versions...\n\n\n" >> bvec_change_log.txt
        rm -f "$BVECNEWFILE"
    fi
    echo -e "\n\n\nTRANSPOSED BVECS IS SAVED AS "$BVECNEWFILE"\n\n\n"
    for ((i=1; i<=${GRADNUM}; i++ )); do
        gx=$(echo ${BVEC[0]} | awk -v x=$i '{print $x}')
        gy=$(echo ${BVEC[1]} | awk -v x=$i '{print $x}')
        gz=$(echo ${BVEC[2]} | awk -v x=$i '{print $x}')
        echo "$gx $gy $gz" >> "$BVECNEWFILE"
    done

    ##Extract white-matter mask for SNR calculation
    echo -e "\n\n\nExtracting SNR estimates for each directional volume...\n\n\n"
    python $autoDTI_HOME/Py_function_library/SNR_estimation.py "$output_dir"/"$PARTIC"/original_data.nii.gz "$output_dir"/"$PARTIC"/bval "$output_dir"/"$PARTIC"/bvec "0.25"
    wait
    if [ -f LOW_SNR_VOLS_LIST.txt ]; then
        high_noise_vols=`cat LOW_SNR_VOLS_LIST.txt`
    fi

    ##Check for venetian blind effect on any individual 3d volumes
    rm -f bad_vols_intraslice.txt 2>/dev/null
    echo -e "\n\n\nUsing interlaced slicewise correlation to check for signal drop-out slices (i.e. the \"venentian blind effect\") across each z-slice of every 3d DWI volume...\n\n\n"
    python $autoDTI_HOME/Py_function_library/venetian_blind_check.py 'eddy_corrected_data.nii.gz' 0.05
    wait
    if [ -f bad_vols_intraslice.txt ]; then
        venetian_blind_vols=`cat bad_vols_intraslice.txt`
    fi

    total_vols=`fslnvols original_data.nii.gz`

    p_trans=`awk '$3 > 2 || $2 > 2 || $1 > 2' *_trans.txt | grep -f - -n *_trans.txt | sed 's/:.*//' | awk '{print $1}'` 2>/dev/null
    n_trans=`awk '$3 < -2 || $2 < -2 || $1 < -2' *_trans.txt | grep -f - -n *_trans.txt | sed 's/:.*//' | awk '{print $1}'` 2>/dev/null
    p_rot=`awk '$3 > 0.2 || $2 > 0.2 || $1 > 0.2' *_rot.txt | grep -f - -n *_rot.txt | sed 's/:.*//' | awk '{print $1}'` 2>/dev/null
    n_rot=`awk '$3 < -0.2 || $2 < -0.2 || $1 < -0.2' *_rot.txt | grep -f - -n *_rot.txt | sed 's/:.*//' | awk '{print $1}'` 2>/dev/null

    echo -e "\n\n\nSplitting original_data.nii.gz into 3d volumes...\n\n\n"
    fslsplit original_data original_data_3d -t
    wait

    if [ ! -z "$p_trans" ] || [ ! -z "$n_trans" ] || [ ! -z "$p_rot" ] || [ ! -z "$n_rot" ] || [ ! -z $venetian_blind_vols ] || [ ! -z $high_noise_vols ]; then
        cp bvec bvec_pre_avr 2>/dev/null
        cp bval bval_pre_avr 2>/dev/null
	wait
    fi
    if [ ! -z "$p_trans" ]; then
        for i in `echo $p_trans`; do
	    j=`echo $(echo $i - 1 | bc)`
            if grep -q "$j" b0_indices_trans 2>/dev/null; then
		continue
	    else
        	echo "Found translation outlier volumes..."
                rm -f "original_data_3d00$j.nii.gz"
                echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
                echo  "\nRemoving volume $j from dataset for excess translation..." >> bvec_change_log.txt
                sed -e "$i"d bvec_trans > tmp_bvec && mv tmp_bvec bvec_trans
		wait
                awk '{$'$i'=""; print $0}' bval | sed 's/  */ /g' > tmp_bval && mv tmp_bval bval
		wait
                echo "Updating bvec and bval files..."
                echo "$j" >> bad_vols.txt
            fi
        done
    fi
    if [ ! -z "$n_trans" ]; then
        for i in `echo $n_trans`; do
	    j=`echo $(echo $i - 1 | bc)`
            if grep -q "$j" b0_indices_trans 2>/dev/null; then
		continue
	    else
        	echo "Found translation outlier volumes..."
                rm -f "original_data_3d00$j.nii.gz"
		echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
                echo  -e "\nRemoving volume $j from dataset for excess translation..." >> bvec_change_log.txt
                sed -e "$i"d bvec_trans > tmp_bvec && mv tmp_bvec bvec_trans
		wait
                awk '{$'$i'=""; print $0}' bval | sed 's/  */ /g' > tmp_bval && mv tmp_bval bval
                wait
                echo "Updating bvec and bval files..."
                echo "$j" >> bad_vols.txt
            fi
        done
    fi
    if [ ! -z "$p_rot" ]; then
        for i in `echo $p_rot`; do
            j=`echo $(echo $i - 1 | bc)`
	    if grep -q "$j" b0_indices_trans 2>/dev/null; then
                continue
	    else
                echo "Found rotation outlier volumes..."
		rm -f "original_data_3d00$j.nii.gz"
                echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
                echo  -e "\nRemoving volume $j from dataset for excess rotation..." >> bvec_change_log.txt
                sed -e "$i"d bvec_trans > tmp_bvec && mv tmp_bvec bvec_trans
		wait
                awk '{$'$i'=""; print $0}' bval | sed 's/  */ /g' > tmp_bval && mv tmp_bval bval
                wait
                echo "Updating bvec and bval files..."
                echo "$j" >> bad_vols.txt
            fi
        done
    fi
    if [ ! -z "$n_rot" ]; then
        for i in `echo $n_rot`; do
            j=`echo $(echo $i - 1 | bc)`
            if grep -q "$j" b0_indices_trans 2>/dev/null; then
		continue
	    else
        	echo "Found rotation outlier volumes..."
                rm -f "original_data_3d00$j.nii.gz"
                echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
                echo -e "\nRemoving volume $j from dataset for excess rotation..." >> bvec_change_log.txt
                sed -e "$i"d bvec_trans > tmp_bvec && mv tmp_bvec bvec_trans
		wait
                awk '{$'$i'=""; print $0}' bval | sed 's/  */ /g' > tmp_bval && mv tmp_bval bval
                wait
                echo "Updating bvec and bval files..."
                echo "$j" >> bad_vols.txt
            fi
        done
    fi

    if [ ! -z "$high_noise_vols" ]; then
        for i in `echo $high_noise_vols`; do
            j=`echo $(echo $i - 1 | bc)`
	    ##Ensure these are not B0 volumes
            if grep -q "$j" b0_indices_trans 2>/dev/null; then
		continue
	    else
        	echo "Found volume(s) with abberant Signal-to-Noise ratio..."
	        rm -f "original_data_3d00$j.nii.gz"
                echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
                echo -e "Removing volume $j from dataset on the basis of its SNR being "$num_SD_low" SD's less-than the average SNR across all direction volumes..." >> bvec_change_log.txt
                sed -e "$i"d bvec_trans > tmp_bvec && mv tmp_bvec bvec_trans
                wait
                awk '{$'$i'=""; print $0}' bval | sed 's/  */ /g' > tmp_bval && mv tmp_bval bval
                wait
                echo "Updating bvec and bval files..."
                echo "$j" >> bad_vols.txt
            fi
        done
    fi

    if [ ! -z "$venetian_blind_vols" ]; then
        for i in `echo $venetian_blind_vols`; do
            j=`echo $(echo $i | bc)`
            ##Ensure these are not B0 volumes
            if grep -q "$j" b0_indices_trans 2>/dev/null; then
                continue
            else
		echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
                echo -e "\nRemoving "$j" from dataset for probable venetian blind striping..." >> bvec_change_log.txt
                rm -f "original_data_3d00$j.nii.gz"
                sed -e "$i"d bvec_trans > tmp_bvec && mv tmp_bvec bvec_trans
                wait
                awk '{$'$i'=""; print $0}' bval | sed 's/  */ /g' > tmp_bval && mv tmp_bval bval
                wait
                echo "Updating bvec and bval files..."
                echo "$j" >> bad_vols.txt
            fi
        done
    fi

    echo -e "\n\n\nMerging 3d volumes back into a 4d file called original_data.nii.gz...\n\n\n"
    fslmerge -t original_data original_data_3d*
    wait

    ##Transpose bvec back to horizontal x,y,z
    awk '
    {
        for (i=1; i<=NF; i++)  {
            a[NR,i] = $i
        }
    }
    NF>p { p = NF }
    END {
        for(j=1; j<=p; j++) {
            str=a[1,j]
            for(i=2; i<=NR; i++){
                str=str" "a[i,j];
            }
            print str
        }
    }' bvec_trans > bvec

    rm -f original_data original_data_3d* 2>/dev/null

    if [ -f bad_vols.txt ]; then
        ##Check bad_vols.txt for too many volumes being removed
        echo -e "\n\n\nChecking percentage of bad volumes...\n\n\n"
        num_bad_vols=`cat bad_vols.txt | wc -l`
        perc_bad_vols=`expr "($num_bad_vols / $total_vols)" | bc -l`

        if (( $(bc <<< "$perc_bad_vols > 0.1") )); then
            echo "WARNING: >10% of volumes auto-removed for excess motion! Consider dropping this subject from analysis."
            exit 0
        elif [[ `cat $i/bvec_trans | wc -l` != `cat $i/bval | wc | awk '{print $2}'` ]]; then
            echo "ERROR: auto volume removal failed-- bvec and bval files have an unequal number of entries!"
            exit 0
        else
            rerun_prep=1
            echo -e "\n\n\nFOUND AND REMOVED $num_bad_vols PROBLEMATIC DWI VOLUMES...\n\n\n"
            echo -e "Creating text file called volumes_removed.txt for record of which volumes were removed, and saving the original bvec and bval files as bvec_pre_avr and bval_pre_avr for reference even though these will not be used for any further preprocessing...\n\n\n"
            mv "$output_dir"/"$PARTIC"/'bad_vols.txt' "$output_dir"/"$PARTIC"/'volumes_removed.txt' 2>/dev/null
	    wait
        fi
    else
        echo -e "\n\n\nNO OUTLIER VOLUMES DETECTED...\n\n\n"
        if [[ $E_switch == 1 ]]; then
            rerun_prep=1
        fi
    fi
fi

##Following automatic volume removal, proceed to restart preprocessing using modified files
if [ -z "$rerun_prep" ]; then
    rerun_prep=0
elif [[ $rerun_prep == 1 ]]; then
    if [ -f volumes_removed.txt ] || [[ $E_switch == 1 ]]; then
        echo -e "Deleting contents of "$output_dir"/"$PARTIC" except for modified original_data.nii.gz, bvec, and bval files..."
        cd "$output_dir"/"$PARTIC"
	ls "$output_dir"/"$PARTIC" | grep -v "original_data.nii.gz" | grep -v "P2A.nii.gz" | grep -v "FieldMap_Phase.nii.gz" | grep -v "FieldMap_Magnitude.nii.gz" | grep -v "bval" | grep -v "bvec" | grep -v "bvec_pre_avr" | grep -v "bval_pre_avr" | grep -v "bad_vols.txt" | xargs rm 2>/dev/null
        rm -rf "$output_dir"/"$PARTIC"/parallel_logs 2>/dev/null
    fi

    ##Reset variables necessary for a re-run
    auto_volrem=0
    noconv=1
    if [[ $E_switch == 1 ]]; then
        eddy_type=1
        E_switch=0
        parcellate=0
	buildsurf=0
    fi
    echo -e "\n\n\nReinitiating preprocessing using modified DWI image with corrected bvec/bval\n\n\n"
    curr_timestamp=$(date +%s)
    elapsed_time=$(expr $curr_timestamp - $start_timestamp)
    echo -e "Elapsed (AVR): "$elapsed_time"\n" >> "$output_dir"/"$PARTIC"/elapsed_time.log
    ##Reinitiate preprocessing
    echo -e "\n\n\nQUALITY CONTROL COMPLETE\nReinitiating preprocessing with updated base dataset...\n\n\n"
    autoDTI.sh "$dwi_dir" "$P2A" "$output_dir" "$OddSlices" "$PARTIC" "$sequence" "$T1directory" "$Study" "$preproc" "$tracula" "$buildsurf" "$probtracking" "$eddy_type" "$bpx" "$parcellate" "$stats" "$NumCores" "$E_switch" "$NRRD" "$parallel_type" "$QA" "$NumCoresMP" "$denoising" "$noconv" "$after_eddy" "$det_tractography" "$fieldmap" "$mag_dir" "$phase_dir" "$rotate_bvecs" "$tensor" "$volrem" "$auto_volrem" "$dwell" "$det_type" "$gpu" "$reinit_check" "$omp_pe" "$view_outs" "$max_gpu_threads" "$TE" "$conversion_type" "$SCANNER" "$Numcoils" "$starting" "$NRRD" "$prep_nodes" "$ALLOCATION" "$debug" "$reslice" "$TOTAL_READOUT"
    exit
fi

##Fieldmap correction option using FUGUE
if [[ $fieldmap == 1 ]]; then
    cd "$output_dir"/"$PARTIC"

    echo -e "\n\n\nAPPLYING FIELDMAP CORRECTION...\n\n\n"

    if [ ! -f nodif_brain.nii.gz ]; then
        ##Extract B0 image
        echo "Extracting B0..."
        fslroi eddy_corrected_data.nii.gz nodif.nii.gz 0 1
        wait

        ##Run BET on B0 image
        echo "Extracting nodif brain mask..."
        bet nodif.nii.gz nodif_brain -m -f $frac_thresh
        wait
    fi

    ##Prepare fieldmap
    echo -e "\n\n\nTE time is "$TE""
    echo -e "Dwell time is "$dwell"\n\n\n"

    echo -e "\n\n\nBrain extracting magnitude image...\n\n\n"
    bet FieldMap_Magnitude.nii.gz FieldMap_Magnitude_brain.nii.gz -f 0.3 -m -g 0.0
    wait

    echo -e "\n\n\nPreparing fieldmap...\n\n\n"
    fsl_prepare_fieldmap "$SCANNER" FieldMap_Phase.nii.gz FieldMap_Magnitude_brain.nii.gz fmap_rads.nii.gz "$TE"
    wait

    echo -e "\n\n\nMasking fieldmap with brain mask from magnitude image...\n\n\n"
    fslmaths fmap_rads.nii.gz -mas FieldMap_Magnitude_brain_mask.nii.gz fmap_rads_brain.nii.gz
    wait

    echo -e "\n\n\nSmoothing newly masked fieldmap image by a factor of $fugue_smooth...\n\n\n"
    fugue --loadfmap=fmap_rads_brain -s "$fugue_smooth" --savefmap="fmap_rads_brain_s"$fugue_smooth""
    wait

    echo -e "\n\n\nWarping the magnitude image according to the deformation specified in the field map...\n\n\n"
    fugue -v -i FieldMap_Magnitude_brain --unwarpdir=y --dwell="$dwell" --loadfmap=fmap_rads.nii.gz -w FieldMap_Magnitude_brain_warpped
    wait

    echo -e "\n\n\nLinearly registering the deformed magnitude image to brain extracted b0 image...\n\n\n"
    flirt -in FieldMap_Magnitude_brain_warpped.nii.gz -ref nodif_brain.nii.gz -out FieldMap_Magnitude_brain_warpped_2_nodif_brain -omat FieldMap_fieldmap2diff.mat
    wait

    echo -e "\n\n\nApplying linear transformation to the field map...\n\n\n"
    flirt -in "fmap_rads_brain_s"$fugue_smooth"" -ref nodif_brain.nii.gz -applyxfm -init FieldMap_fieldmap2diff.mat -out "fmap_rads_brain_"$fugue_smooth"_2_nodif_brain"
    wait

    echo -e "\n\n\nUndistorting the eddy corrected dataset using the smoothed, brain-masked, and registered field map...\n\n\n"
    fugue -v -i eddy_corrected_data.nii.gz --icorr --unwarpdir=y --dwell="$dwell" --loadfmap="fmap_rads_brain_"$fugue_smooth"_2_nodif_brain.nii.gz" -u eddy_corrected_data_FMC.nii.gz
    wait

    echo -e "\n\n\nFIELDMAP CORRECTION COMPLETE\n\n\n"

    ##Clean up temp files (hastag as needed for debugging)
    rm -f nodif.nii.gz
    rm -f fmap_rads_brain*
    rm -f FieldMap_fieldmap2diff.mat
fi

##Rotate bvec file to match eddy correction
if [[ $rotate_bvecs == 1 ]] && [ ! -f "$output_dir"/"$PARTIC"/bvec_orig ]; then
    echo -e "\n\n\nROTATING BVEC FILE...\n\n\n"
    if [ -f "$output_dir"/"$PARTIC"/eddy_corrected_data.ecclog ]; then
        echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
        echo -e "\n\n\nROTATING BVEC FILE BASED ON OUTPUT FROM eddy_correct...\n\n\n"  >> bvec_change_log.txt
        fdt_rotate_bvecs bvec bvec_rotated eddy_corrected_data.ecclog
        wait
        mv -v "$output_dir"/"$PARTIC"/bvec "$output_dir"/"$PARTIC"/bvec_orig 2>/dev/null
        wait
        mv -v "$output_dir"/"$PARTIC"/bvec_rotated "$output_dir"/"$PARTIC"/bvec 2>/dev/null
        wait
    elif [ -f "$output_dir"/"$PARTIC"/eddy_corrected_data.nii.gz.eddy_rotated_bvecs ]; then
        echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
	echo -e "\n\n\nUSING ROTATED BVEC FILE AUTOMATICALLY OUTPUT FROM eddy...\n\n\n"  >> bvec_change_log.txt
        mv -v "$output_dir"/"$PARTIC"/bvec "$output_dir"/"$PARTIC"/bvec_orig 2>/dev/null
        wait
        mv -v "$output_dir"/"$PARTIC"/eddy_corrected_data.nii.gz.eddy_rotated_bvecs "$output_dir"/"$PARTIC"/bvec 2>/dev/null
	wait
    elif [ -f "$output_dir"/"$PARTIC"/eddy_corrected_data.nii.gz.eddy_parameters ]; then
        echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
	echo -e "\n\n\nROTATING BVEC FILE BASED ON OUTPUT FROM eddy...\n\n\n"  >> bvec_change_log.txt

        ##Run python eddy rotation script
        in_bvec="$output_dir"/"$PARTIC"/bvec
        eddy_params="$output_dir"/"$PARTIC"/eddy_corrected_data.nii.gz.eddy_parameters
        eddy_rotate_bvecs.py $in_bvec $eddy_params
        wait

        mv -v "$output_dir"/"$PARTIC"/bvec "$output_dir"/"$PARTIC"/bvec_orig 2>/dev/null
        wait
        mv -v "$output_dir"/"$PARTIC"/bvec_rotated.bvec "$output_dir"/"$PARTIC"/bvec 2>/dev/null
	wait
    fi
fi

##Specify name of input to denoising algorithms depending on whether or not FUGUE fieldmap correction was applied
if [[ $fieldmap == 1 || $fieldmap == 2 ]] || [ -f "$output_dir"/"$PARTIC"/eddy_corrected_data_FMC.nii.gz ]; then
    input="eddy_corrected_data_FMC.nii.gz"
else
    input="eddy_corrected_data.nii.gz"
fi

##Denoising options
if [[ $denoising == "NLSAM" ]] || [[ $denoising == "NLMEANS" ]]; then
    echo -e "\n\n\nRUNNING DENOISING...\n\n\n"
    ##Determine N
    if [[ $SCANNER == SIEMENS ]]; then
	if [ "$Numcoils" -eq "32" ]; then
	    N=4
	elif [ "$Numcoils" -eq "16" ]; then
	    N=2
	else
	    N=1
        fi
    else
        N=1
    fi

    if [ ! -f bet.nii.gz ]; then
        ##Run BET on eddy output
        bet ""$input".nii.gz" bet.nii.gz -m -f $frac_thresh
        wait
    fi

    if [[ $denoising == "NLSAM" ]]; then
        ##Determine number of z slices to determine max_threads
        z_slices=`fslval "$output_dir"/"$PARTIC"/original_data.nii.gz dim3`

        if [ "$NumCores" -ge "$z_slices" ]; then
            NumCoresNLSAM="$z_slices"

            #Reset omp cores if z_slices check succeeds
            NumCoresMP="$NumCoresNLSAM"
        fi
      	export OMP_NUM_THREADS="$NumCoresMP"
      	##NLSAM
      	nlsam_denoising "$output_dir"/"$PARTIC"/"$input" "$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz $N "$output_dir"/"$PARTIC"/bval "$output_dir"/"$PARTIC"/bvec 5 -m "$output_dir"/"$PARTIC"/bet_mask.nii.gz --cores $NumCoresMP -f
      	wait
    elif [[ $denoising == "NLMEANS" ]]; then
      	##NLMEANS
	N=1
      	$autoDTI_HOME/Py_function_library/denoise.py "$output_dir"/"$PARTIC"/"$input" "$output_dir"/"$PARTIC"/bval "$output_dir"/"$PARTIC"/bvec "$output_dir"/"$PARTIC"/"bet_mask.nii.gz" "$N"

	fslmerge -t eddy_corrected_data_denoised.nii.gz `ls -1v *denoised_tmp.nii.gz`
	rm -f *denoised_tmp.nii.gz
      	wait
    fi
    curr_timestamp=$(date +%s)
    elapsed_time=$(expr $curr_timestamp - $start_timestamp)
    echo -e "Elapsed (Denoising): "$elapsed_time"\n" >> "$output_dir"/"$PARTIC"/elapsed_time.log
fi

if [ -z $denoising ] && [ ! -f "$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz ]; then
    mv -v "$output_dir"/"$PARTIC"/""$input".nii.gz" "$output_dir"/"$PARTIC"/eddy_corrected_data_nodenoised.nii.gz 2>/dev/null
    wait
fi

##Set preprocessed image input depending on whether denoising options were used
if [ -f "$output_dir"/"$PARTIC"/eddy_corrected_data_denoised.nii.gz ]; then
    preprocessed_img=eddy_corrected_data_denoised.nii.gz
elif [ -f "$output_dir"/"$PARTIC"/eddy_corrected_data_nodenoised.nii.gz ]; then
    preprocessed_img=eddy_corrected_data_nodenoised.nii.gz
fi

if [ -z "$preprocessed_img" ]; then
    echo -e "\n\n\n\n\n`date`" >> bvec_change_log.txt
    echo -e "\nTransposing bvec file..." >> bvec_change_log.txt

    ##Transpose bvecs rows to columns
    ##Read in the bvecs file
    BVECFILE=bvec
    BVECNEWFILE="bvec_dtk"
    ##Store it as an array
    c=0; while read line; do BVEC[c]=`echo "$line"`; let c=$c+1; done < "$BVECFILE"
    BVECNUM=${#BVEC[@]}
    ##Check the number of directions
    GRADNUM=$(echo "$BVEC" | wc -w )
    ##Indexing at i=1 so we get rid of the first vol0 indexed as 0
    if [ -f "$BVECNEWFILE" ]; then
        echo -e "\n\n\n"$BVECNEWFILE" already exists. Numbering new versions...\n\n\n" >> bvec_change_log.txt
        rm -f "$BVECNEWFILE"
    fi
    echo -e "\n\n\nTRANSPOSED BVECS IS SAVED AS "$BVECNEWFILE"\n\n\n"
    for ((i=1; i<=${GRADNUM}; i++ )); do
        gx=$(echo ${BVEC[0]} | awk -v x=$i '{print $x}')
        gy=$(echo ${BVEC[1]} | awk -v x=$i '{print $x}')
        gz=$(echo ${BVEC[2]} | awk -v x=$i '{print $x}')
        echo "$gx $gy $gz" >> "$BVECNEWFILE"
    done
fi

##Convert preprocessed image to isotropic voxels
if [[ $reslice == 1 ]]; then
    cd "$output_dir"/"$PARTIC"
    python -W ignore $autoDTI_HOME/Py_function_library/reslice_to_iso.py $preprocessed_img
    echo "CONVERTED $preprocessed_img TO ISOTROPIC file iso_"$preprocessed_img"" >  ani2iso.log
    preprocessed_img="iso_"$preprocessed_img""
fi

##Run NRRD conversion for 3D slicer
if [[ $NRRD == 1 ]]; then
    if [ -z "$preprocessed_img" ]; then
        echo -e "\n\n\nPreprocessed image not found. Check "$output_dir"/"$PARTIC" to be sure either eddy_corrected_data_denoised.nii.gz or eddy_corrected_data_nodenoised.nii.gz actually exist. If not, re-run preprocessing."
        exit
    fi

    ##DWI Conversion to .nrrd for Slicer
    echo -e "\n\n\nCREATING .nrrd FORMATTED FILE FOR 3DSlicer...\n\n\n"
    DWIConvert --inputVolume "$preprocessed_img" --conversionMode FSLToNrrd --inputBValues bval --inputBVectors bvec_dtk --outputVolume ""$PARTIC".nrrd"
    wait
fi

touch "DONE_PREPROCESSING"
echo -e "\n\n\nDONE PREPROCESSING DATA. FINAL PREPROCESSED NIFTI IMAGE FILE IS: \n"$output_dir"/"$PARTIC"/"$preprocessed_img""
curr_timestamp=$(date +%s)
elapsed_time=$(expr $curr_timestamp - $start_timestamp)
echo -e "Elapsed (Preprocessing Stage): "$elapsed_time"\n" >> "$output_dir"/"$PARTIC"/elapsed_time.log

exit 0
