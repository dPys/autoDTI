#!/bin/bash

## Check if openDTI_HOME variable exists, then check if the actual
## directory exists.
if [ -z "$openDTI_HOME" ]; then
    echo "ERROR: environment variable openDTI_HOME is not defined"
    echo "       Run the command 'export openDTI_HOME=<main_dir>"
    echo "       where <main_dir> is the directory where openDTI"
    echo "       is installed."
    return 1;
fi

##Export paths to scripts
export PATH=$PATH:"$openDTI_HOME"/Batch_scripts
export PATH=$PATH:"$openDTI_HOME"/Main_scripts
export PATH=$PATH:"$openDTI_HOME"/Stage_scripts
export PATH=$PATH:"$openDTI_HOME"/Py_function_library
export PATH=$PATH:"$openDTI_HOME"/3rd_party_scripts_library/DTI_TK
export PATH=$PATH:"$openDTI_HOME"/3rd_party_scripts_library/Conversion_scripts
export PATH=$PATH:"$openDTI_HOME"/3rd_party_scripts_library/Motion_plotting_scripts
export PATH=$PATH:"$openDTI_HOME"/3rd_party_scripts_library/Py_function_library
export PATH=$PATH:"$openDTI_HOME"/3rd_party_scripts_library/QAtools
