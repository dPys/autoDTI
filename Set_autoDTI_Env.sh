#!/bin/bash

## Check if autoDTI_HOME variable exists, then check if the actual
## directory exists.
if [ -z "$autoDTI_HOME" ]; then
    echo "ERROR: environment variable autoDTI_HOME is not defined"
    echo "       Run the command 'export autoDTI_HOME=<main_dir>"
    echo "       where <main_dir> is the directory where autoDTI"
    echo "       is installed."
    return 1;
fi

##Export paths to scripts
export PATH=$PATH:"$autoDTI_HOME"/Batch_scripts
export PATH=$PATH:"$autoDTI_HOME"/Main_scripts
export PATH=$PATH:"$autoDTI_HOME"/Stage_scripts
export PATH=$PATH:"$autoDTI_HOME"/Py_function_library
export PATH=$PATH:"$autoDTI_HOME"/3rd_party_scripts_library/DTI_TK
export PATH=$PATH:"$autoDTI_HOME"/3rd_party_scripts_library/Conversion_scripts
export PATH=$PATH:"$autoDTI_HOME"/3rd_party_scripts_library/Motion_plotting_scripts
export PATH=$PATH:"$autoDTI_HOME"/3rd_party_scripts_library/Py_function_library
export PATH=$PATH:"$autoDTI_HOME"/3rd_party_scripts_library/QAtools
