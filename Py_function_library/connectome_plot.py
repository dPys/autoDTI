#!/usr/bin/env python

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

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import nibabel
import codecs
import os
import sys

BASE_loc=sys.argv[1]
LABELS_loc=sys.argv[2]
ROIS_loc=sys.argv[3]

def collapse_probtrack_results(waytotal_file, matrix_file):
    waytotal = eval(str(np.loadtxt(waytotal_file)))
    with codecs.open(matrix_template, encoding='utf-8-sig') as f:
        data = np.loadtxt(f)
    if waytotal==0:
	waytotal=1
    collapsed =  (data.sum(axis=0) / (waytotal)) * 1000
    return collapsed

processed_seed_list = [s.replace('.nii.gz','').replace(ROIS_loc, '') for s in open(LABELS_loc).read().split('\n') if s]
N = len(processed_seed_list)
conn = np.zeros((N, N))
rois=[]
idx = 0
for roi in processed_seed_list:
    paths_dir = 'paths_' + str(roi)
    seed_directory=os.path.join(BASE_loc,paths_dir)
    matrix_template = os.path.join(seed_directory,'matrix_seeds_to_all_targets.asc')
    matrix_file = matrix_template.format(roi=roi)
    waytotal_file = os.path.join(seed_directory,'waytotal')
    rois.append(roi)
    try:
        # if this particular seed hasn't finished processing, you can still
        # build the matrix by catching OSErrors that pop up from trying
        # to open the non-existent files
        conn[idx, :] = collapse_probtrack_results(waytotal_file, matrix_file)
    except OSError:
        pass
    idx += 1

# figure plotting
fig = plt.figure()
ax = fig.add_subplot(111)
cax = ax.matshow(conn, interpolation='nearest', )
cax.set_cmap('hot')
caxes = cax.get_axes()

# set number of ticks
caxes.set_xticks(range(len(processed_seed_list)))
caxes.set_yticks(range(len(processed_seed_list)))

# label the ticks
caxes.set_xticklabels(processed_seed_list, rotation=90, fontsize=6)
caxes.set_yticklabels(processed_seed_list, rotation=0, fontsize=6)

# axes labels
caxes.set_xlabel('Target ROI', fontsize=16)
caxes.set_ylabel('Seed ROI', fontsize=16)

# Colorbar
cbar = fig.colorbar(cax)
cbar.set_label('% of streamlines from seed to target', rotation=-90, fontsize=18)

# title text
title_text = ax.set_title('Structural Connectivity',
    fontsize=20)
title_text.set_position((.5, 1.10))

#Show plot
plt.show(fig)
