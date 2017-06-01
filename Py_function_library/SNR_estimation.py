#!/usr/env python
from __future__ import division, print_function
import nibabel as nib
import numpy as np
from dipy.segment.mask import median_otsu
from dipy.reconst.dti import TensorModel
from dipy.align.reslice import reslice
from dipy.data import get_data
from scipy.ndimage.morphology import binary_dilation
from dipy.segment.mask import segment_from_cfa
from dipy.segment.mask import bounding_box
from dipy.core.gradients import gradient_table
from dipy.io import read_bvals_bvecs
import matplotlib.pyplot as plt
import os
import sys

#############
##Image inputs
fimg=sys.argv[1]
fbval= sys.argv[2]
fbvec= sys.argv[3]

##Rejection threshold of mean SNR across all volumes
x= sys.argv[4]
#############

##Load image
img = nib.load(fimg)
data = img.get_data()
affine = img.get_affine()

#loading bvecs/bvals
bvals, bvecs = read_bvals_bvecs(fbval, fbvec)

#Creating the gradient table
gtab = gradient_table(bvals, bvecs)

#Correct b0 threshold
gtab.b0_threshold = min(bvals)

#Correct b0s_mask
gtab.b0s_mask = gtab.bvals == gtab.b0_threshold

#Get B0 indices
B0s_list = np.where(gtab.bvals == gtab.b0_threshold)[0]

print('Computing brain mask...')
b0_mask, mask=median_otsu(data)

print('Computing tensors...')
tenmodel=TensorModel(gtab)
tensorfit=tenmodel.fit(data, mask=mask)

print('Computing worst-case/best-case SNR using the corpus callosum...')
threshold = (0.6, 1, 0, 0.1, 0, 0.1)
CC_box = np.zeros_like(data[..., 0])

mins, maxs = bounding_box(mask)
mins = np.array(mins)
maxs = np.array(maxs)
diff = (maxs - mins) // 4
bounds_min = mins + diff
bounds_max = maxs - diff

CC_box[bounds_min[0]:bounds_max[0],
       bounds_min[1]:bounds_max[1],
       bounds_min[2]:bounds_max[2]] = 1

mask_cc_part, cfa = segment_from_cfa(tensorfit, CC_box,
                                   threshold, return_cfa=True)

cfa_img = nib.Nifti1Image((cfa*255).astype(np.uint8), affine)
mask_cc_part_img = nib.Nifti1Image(mask_cc_part.astype(np.uint8), affine)
nib.save(mask_cc_part_img, 'mask_CC_part.nii.gz')

region = 40
fig = plt.figure('Corpus callosum segmentation')
plt.subplot(1, 2, 1)
plt.title("Corpus callosum (CC)")
plt.axis('off')
red = cfa[..., 0]
plt.imshow(np.rot90(red[region, ...]))

plt.subplot(1, 2, 2)
plt.title("CC mask used for SNR computation")
plt.axis('off')
plt.imshow(np.rot90(mask_cc_part[region, ...]))
fig.savefig("CC_segmentation.png", bbox_inches='tight')

mean_signal = np.mean(data[mask_cc_part], axis=0)
mask_noise = binary_dilation(mask, iterations=10)
mask_noise[..., :mask_noise.shape[-1]//2] = 1
mask_noise = ~mask_noise
mask_noise_img = nib.Nifti1Image(mask_noise.astype(np.uint8), affine)
nib.save(mask_noise_img, 'mask_noise.nii.gz')

noise_std = np.std(data[mask_noise, :])
print('Noise standard deviation sigma= ', noise_std)

direction_num = len(gtab.bvals) 
SNR_dirs = np.zeros((direction_num,2))
i = 0
for direction in range(direction_num):
      SNR = mean_signal[direction]/noise_std
      print("SNR for direction", direction, " ", gtab.bvecs[direction], "is: ", SNR)
      SNR_dirs[i, 0] = i
      SNR_dirs[i, 1] = SNR
      i = i + 1

np.where(gtab.bvals == gtab.b0_threshold)[0]

##Unselect volumes with SNR <= 0
SNR_dirs = SNR_dirs[np.logical_not(SNR_dirs[:,1] <= 0)]

##Unselect volumes that are B0's
SNR_dirs = SNR_dirs[np.logical_not(gtab.b0s_mask == True)]

##Get mean SNR across remaining volumes
mean_SNR = np.mean(SNR_dirs[:,1])

##Get list of volumes where SNR is less than x% of the mean
SNR_bad_vols = list(SNR_dirs[np.logical_not(SNR_dirs[:,1] > float(x)*mean_SNR)][:,0])
SNR_list_str = '\t'.join(str(x).rstrip('.0') for x in SNR_bad_vols)

print('Low SNR volumes detected at ' + str(SNR_bad_vols).strip('[]') + ' using a ' + str(x) + '% of mean SNR rejection threshold')
with open('LOW_SNR_VOLS_LIST.txt', mode='wt') as file:
    file.write(SNR_list_str)
