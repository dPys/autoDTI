#!/usr/bin/env  python
import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt
from time import time
from dipy.io import read_bvals_bvecs
from dipy.denoise.nlmeans import nlmeans
from dipy.denoise.noise_estimate import estimate_sigma
import sys
import os

fimg=sys.argv[1]
fbval=sys.argv[2]
fbvec=sys.argv[3]
bet=sys.argv[4]
##Load data and affine
img=nib.load(fimg)
data=img.get_data()
data.shape
affine=img.get_affine()

##Load bvecs/bvals, determine volume total, and B0 threshold
bvals, bvecs = read_bvals_bvecs(fbval, fbvec)
B0_thresh = int(min(bvals))
TOTAL_VOLUMES = len(bvals)
num_slices = data.shape[2]
print("vol size", data.shape)

#Get B0 indices
B0s_list = list(np.where(bvals == B0_thresh)[0])

##Load BET mask
bet_img=nib.load(bet)
bet_data=bet_img.get_data()
mask = bet_data > 0

##Get coil info, if available, to set N
try:
   N = os.environ["N"]
except:
   pass
try:
   N
except NameError:
   try:
        N = sys.argv[5]
   except:
        N = 1

##Set timer
t = time()

##Create a variable called all_vols and start by adding the first volume to it
dwi_vols = [x for x in range(TOTAL_VOLUMES) if x not in B0s_list]
for i in dwi_vols:
   
    vol = data[..., i]
    sigma = estimate_sigma(vol, N=4)
    den = nlmeans(vol, sigma=sigma, mask=mask)

    print("total time", time() - t)
    print("vol size", den.shape)

    nib.save(nib.Nifti1Image(den, affine), str(i) + '_denoised_tmp.nii.gz')

##Extract B0s
for i in B0s_list:
    vol = data[..., i]
    nib.save(nib.Nifti1Image(vol, affine), str(i) + '_denoised_tmp.nii.gz')

##Use the last volume for comparison
before = vol[:, :, axial_middle].T
after = vol[:, :, axial_middle].T
difference = np.abs(after.astype('f8') - before.astype('f8'))
difference[~mask[:, :, axial_middle].T] = 0

##Plot example volume before-after-difference picture
fig, ax = plt.subplots(1, 3)
ax[0].imshow(before, cmap='gray', origin='lower')
ax[0].set_title('before')
ax[1].imshow(after, cmap='gray', origin='lower')
ax[1].set_title('after')
ax[2].imshow(difference, cmap='gray', origin='lower')
ax[2].set_title('difference')
for i in range(3):
    ax[i].set_axis_off()

#plt.show()
plt.savefig('denoising.png', bbox_inches='tight')
