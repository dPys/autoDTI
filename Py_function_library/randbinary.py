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

import numpy as np, sys

#Check inputs:
if len(sys.argv)!=3:
    print('Error: invalid x and y')

else:
    #Return "random" binary value according to user-specified proabability weights:
    x=sys.argv[1]
    y=sys.argv[2]
    pWeights=[x,y]
    choices=[0,1]
    rnd=np.random.choice(choices, p=pWeights)

    print(rnd)
