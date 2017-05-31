#!/usr/bin/env python

#Rotates the input bvec file accordingly with a list of parameters sourced from 'eddy', as explained here:
#<http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/EDDY/Faq#Will_eddy_rotate_my_bevcs_for_me.3F>

import sys
import os
import numpy as np
from math import sin, cos

def eddy_rotate_bvecs(in_bvec, eddy_params):
    name, fext = os.path.splitext(os.path.basename(in_bvec))
    if fext == '.gz':
        name, _ = os.path.splitext(name)
    out_file = os.path.abspath('%s_rotated.bvec' % name)
    bvecs = np.loadtxt(in_bvec).T
    new_bvecs = []

    params = np.loadtxt(eddy_params)

    if len(bvecs) != len(params):
        raise RuntimeError(('Number of b-vectors and rotation '
                            'matrices should match.'))

    for bvec, row in zip(bvecs, params):
        if np.all(bvec == 0.0):
            new_bvecs.append(bvec)
        else:
            ax = row[3]
            ay = row[4]
            az = row[5]

            Rx = np.array([[1.0, 0.0, 0.0],
                           [0.0, cos(ax), -sin(ax)],
                           [0.0, sin(ax), cos(ax)]])
            Ry = np.array([[cos(ay), 0.0, sin(ay)],
                           [0.0, 1.0, 0.0],
                           [-sin(ay), 0.0, cos(ay)]])
            Rz = np.array([[cos(az), -sin(az), 0.0],
                           [sin(az), cos(az), 0.0],
                           [0.0, 0.0, 1.0]])
            R = Rx.dot(Ry).dot(Rz)

            invrot = np.linalg.inv(R)
            newbvec = invrot.dot(bvec)
            new_bvecs.append(newbvec / np.linalg.norm(newbvec))

    np.savetxt(out_file, np.array(new_bvecs).T, fmt='%0.15f')
    return out_file

in_bvec=sys.argv[1]
eddy_params=sys.argv[2]

eddy_rotate_bvecs(in_bvec, eddy_params)
