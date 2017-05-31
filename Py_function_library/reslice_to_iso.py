#!/bin/env python
import nibabel as nib
from dipy.align.reslice import reslice
from dipy.data import get_data
import os
import sys

fimg=sys.argv[1]
img=nib.load(fimg)
data=img.get_data()
data.shape
affine=img.get_affine()
zooms=img.get_header().get_zooms()[:3]
new_zooms=(2.,2.,2.)
data2, affine2 = reslice(data, affine, zooms, new_zooms)
img2 = nib.Nifti1Image(data2, affine2, header=img.header)
img2.header['qform_code'] = 2
output = 'iso_' + str(fimg)
nib.save(img2, output)
