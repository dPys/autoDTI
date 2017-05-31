#!/usr/bin/env  python
import nibabel as nib
import matplotlib.pyplot as plt
from time import time
from dipy.denoise.nlmeans import nlmeans
from dipy.denoise.noise_estimate import estimate_sigma
import sys

fimg=sys.argv[1]
img=nib.load(fimg)
data=img.get_data()
data.shape
affine=img.get_affine()

mask = data[..., 0] > 80

#print("vol size", data.shape)

t = time()

sigma = estimate_sigma(data, N=4)
den = nlmeans(data, sigma=sigma, mask=mask)

print("total time", time() - t)
print("vol size", den.shape)

axial_middle = data.shape[2] / 2

before = data[:, :, axial_middle].T
after = den[:, :, axial_middle].T
difference = np.abs(after.astype('f8') - before.astype('f8'))
difference[~mask[:, :, axial_middle].T] = 0

fig, ax = plt.subplots(1, 3)
ax[0].imshow(before, cmap='gray', origin='lower')
ax[0].set_title('before')
ax[1].imshow(after, cmap='gray', origin='lower')
ax[1].set_title('after')
ax[2].imshow(difference, cmap='gray', origin='lower')
ax[2].set_title('difference')
for i in range(3):
    ax[i].set_axis_off()

plt.show()
plt.savefig('denoised.png', bbox_inches='tight')
