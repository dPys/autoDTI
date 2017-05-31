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
PARTIC=${1}
Study=${2}
NumCores=${3}
parallel_type=${4}
NumCoresMP=${5}
tracdir=${6}
debug=${7}
output_dir=${8}

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

#### Use TRACULA ouput to a convenient .csv file for further statistical analysis in your favorite software package (e.g. SPSS, SAS, R) ####

#################################################################
###*Note: these configurations must stay consistent when batching multiple subjects, otherwise headers will be scrambled

##User configured metric type (e.g. Avg, Avg_Weight, Avg_Center)
metric=Avg_Weight 

##User configured tract list from which to extract tract metrics (vertical string list)
tracts='fmajor_PP_avg33_mni_bbr
fminor_PP_avg33_mni_bbr
lh.atr_PP_avg33_mni_bbr
lh.cab_PP_avg33_mni_bbr
lh.ccg_PP_avg33_mni_bbr
lh.cst_AS_avg33_mni_bbr
lh.ilf_AS_avg33_mni_bbr
lh.slfp_PP_avg33_mni_bbr
lh.slft_PP_avg33_mni_bbr
lh.unc_AS_avg33_mni_bbr
rh.atr_PP_avg33_mni_bbr
rh.cab_PP_avg33_mni_bbr
rh.ccg_PP_avg33_mni_bbr
rh.cst_AS_avg33_mni_bbr
rh.ilf_AS_avg33_mni_bbr
rh.slfp_PP_avg33_mni_bbr
rh.slft_PP_avg33_mni_bbr
rh.unc_AS_avg33_mni_bbr'

diff_measures=FA,MD,RD,AD ##List diffusion measures of interest

global_FA=1 ##Set to 1 if you wish to extract global FA using the output from DTIFIT

#################################################################
export SUBJECTS_DIR="$Study"/"$tracdir"/diffusion_recons
source $FREESURFER_HOME/SetUpFreeSurfer.sh

##Convert output to table format for group analysis
rm -rf "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats
mkdir -p "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/export
mkdir -p "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/tables

##Create text file containing list of tracts of interest
echo "$tracts" > "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/TRACULA_tracts.txt

##Remove all tracts from TRACULA_tracts.txt that were found to be problematic if reinit was used
if [ -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/UNUSUABLE_TRACTS.txt ] && [ ! -s "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/UNUSUABLE_TRACTS.txt ]; then
    grep -v -x -f "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/TRACULA_tracts.txt "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/UNUSUABLE_TRACTS.txt
fi

##Create tract vector
filename_tract="$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/TRACULA_tracts.txt
filelines_tracts=`cat $filename_tract`

##Rearrange diffusion measures of interest into an alphabetized list
diff_measures=`echo "$diff_measures" | tr , "\n" | sort | tr "\n" , | sed 's@\(.*\),@\1\n@'`

##Extract each diffusion measure of interest for each tract of interest
for i in $(echo $diff_measures | sed "s/,/ /g"); do
    for tract in $filelines_tracts; do        
	tractstats2table --inputs "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dpath/$tract/pathstats.overall.txt --overall --only-measures "$i"_"$metric" --tablefile "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/tables/"$i"_"$metric"."$tract".table
        echo "$i"."$tract" | cut -f1 -d"_"  > "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/export/"$i"_"$metric"."$tract".num
        cat "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/tables/"$i"_"$metric".$tract.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/export/"$i"_"$metric"."$tract".num
    done
done

##Extract global FA
if [[ $global_FA == 1 ]]; then
    rm "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/export/AA_Global_FA* 2>/dev/null
    echo "Global_FA" > "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/export/AA_Global_FA.num
    echo `fslstats "$Study"/"$tracdir"/tractography_output/"$PARTIC"/dmri/dtifit_FA.nii.gz -m` >> "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/export/AA_Global_FA.num
fi

##Combined output into single text file
ls -v "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/export/* | xargs paste > "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/ALLTRACTS_"$PARTIC"

cd "$Study"/"$tracdir"/tractography_output

##Create headers for database file
if [ ! -f "$Study"/"$tracdir"/tractography_output/database.csv ]; then
    touch "$Study"/"$tracdir"/tractography_output/database.csv
    echo -e "\n\n\nCreating new database file...\n\n\n"
    if [[ $global_FA == 1 ]]; then
        Headers="Partic\tGlobal_FA\t"
    else
        Headers="Partic\t"
    fi
    for i in $(echo $diff_measures | sed "s/,/ /g"); do
        for tract in $filelines_tracts; do
            tract_abbr=`echo "$tract" | awk -F'_' '{print $1}'`       
            Headers=`echo "$Headers""$i"_"$metric"."$tract_abbr""\t"`
        done
    done
    echo -e "$Headers" >> "$Study"/"$tracdir"/tractography_output/database.csv
fi

##Append stats to delimited database file
if [ -e "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/ALLTRACTS_"$PARTIC" ]; then
    echo -e "\n\n\nCreating line for "$PARTIC"..."
    sed -n -e 's/^/\t/' -e 's/^/'"$PARTIC"'/' -e '2{p;q}' "$Study"/"$tracdir"/tractography_output/"$PARTIC"/stats/ALLTRACTS_"$PARTIC" >> "$Study"/"$tracdir"/tractography_output/database.csv
    echo -e "\n\n\nLine created.\n\n\n"
else
    echo -e "\n\n\n"$PARTIC" is missing ALLTRACTS data"
    exit 1
fi

exit 0
