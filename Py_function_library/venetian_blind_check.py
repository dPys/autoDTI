#!/usr/bin/env python

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

import os
import nibabel as nib
import numpy as np
import sys
from os import path

def mean(numbers):
    return float(sum(numbers)) / max(len(numbers), 1)

##Remove any existing bad_vols file
if os.path.exists('bad_vols_intraslice.txt'):
    os.remove('bad_vols_intraslice.txt')

##Remove any existing run log file
if os.path.exists('logfile_venetian_blinds'):
    os.remove('logfile_venetian_blinds')

#Check inputs:
if __name__=="__main__" :
    if len(sys.argv) != 3:
        print('Error: Invalid command line arguments. Run venetian_blind_check.py {file path to nifti file} {difference_threshold (e.g. 0.05 recommended)}')


##Print std.out to log file
class Tee(object):
    def __init__(self, *files):
        self.files = files
    def write(self, obj):
        for f in self.files:
            f.write(obj)

f = open('logfile_venetian_blinds', 'w')
backup = sys.stdout
sys.stdout = Tee(sys.stdout, f)

np.seterr(divide='ignore', invalid='ignore')

input_img=sys.argv[1]
diff_thresh=sys.argv[2]

#Load nifti file
img=nib.load(input_img)

#Get Header dims
header=img.header
[x, y, z, d] = header.get_data_shape()

##Get b0 indices to a list
f = open("b0_indices_trans", "r")
lines = f.read()
f.close()
B0s_tmp = [w for w in (x.strip() for x in lines.splitlines()) if w]
B0s = [ int(x) for x in B0s_tmp ]

print('B0\'s found at: ' + str(B0s))
#breakloops = 0

for vol in range(d):
    #if breakloops == 1:
        #break

    if vol not in B0s:
        #Create slice dictionary
        mean_slices = dict()

        #Create correlation dictionary
        corr_slices=dict()

	np_img_Z_means = np.array([])
	np_img_j_means = np.array([])
	np_img_k_means = np.array([])

        #Get signal intensity average across all voxels of each slice
        for Z in range(z - 1):
	    for Y in range(y):
	        ##Convert image to a numpy array
	        np_img_Z_tmp = np.array(img.get_data()[:,Y,Z,int(vol)],dtype=float)
		np_img_Z_means = np.append(np_img_Z_means,np_img_Z_tmp.mean())
		#print(np_img_Z_means)
 
	        ##Repeat for slice below
	        j = Z - 1
	        ##Convert image to a numpy array
	        np_img_j_tmp = np.array(img.get_data()[:,Y,j,int(vol)],dtype=float)
		np_img_j_means = np.append(np_img_j_means,np_img_j_tmp.mean())
		#print(np_img_j_means)

	        ##Repeat for slice above
	        k = Z + 1
	        ##Convert image to a numpy array
	        np_img_k_tmp = np.array(img.get_data()[:,Y,k,int(vol)],dtype=float)
		np_img_k_means = np.append(np_img_k_means,np_img_k_tmp.mean())
		#print(np_img_k_means)

		jz_corr = np.corrcoef(np_img_Z_means, np_img_j_means)
	        kz_corr = np.corrcoef(np_img_Z_means, np_img_k_means)
		jk_corr = np.corrcoef(np_img_j_means, np_img_k_means)
                print("Running slicewise intensity checks for slice " + str(Z) + " of volume " + str(vol) + ": \n" + "corr(z-1,z): " + str(100*jz_corr[0,1]) + "% " + "corr(z+1,z): " + str(100*kz_corr[0,1]) + "% " + "corr(z-1,z+1): " + str(100*jk_corr[0,1]) + "%")

		if np.isnan(jz_corr[0,1]) == True or np.isnan(kz_corr[0,1]) == True or np.isnan(jk_corr[0,1]) == True:
		    continue

		#print(jz_corr[0,1])
		#print(kz_corr[0,1])
		#print(jk_corr[0,1])

	        jz_kz_diff = abs(jz_corr[0,1] - kz_corr[0,1])
	        jz_jk_diff = abs(jz_corr[0,1] - jk_corr[0,1])
	        jk_kz_diff = abs(jk_corr[0,1] - kz_corr[0,1])

		##Find the average of the x,y,z differences
		#mean_diff = mean([jz_kz_diff,jz_jk_diff,jk_kz_diff])
		#print('Average difference of slicewise correlations across x,y,z: ' + str(mean_diff))
		print(jz_kz_diff)
		print(jz_jk_diff)
		print(jk_kz_diff)
		print('\n\n')

	if float(jz_kz_diff) > float(diff_thresh) or float(jz_jk_diff) > float(diff_thresh) or float(jk_kz_diff) > float(diff_thresh):
	    print('\n\n\n' + "Flagged Volume " + str(vol) + '\n\n\n')
            bad_vols_intraslice = open("bad_vols_intraslice.txt", "a+")
            bad_vols_intraslice.write(str(vol) + "\n")
            bad_vols_intraslice.close()
	    #breakloops = 1

