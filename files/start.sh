#!/bin/bash

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

: ${WORKERS:-8}

. /usr/share/GNUstep/Makefiles/GNUstep.sh
/usr/sbin/sogod -WOWorkersCount "$WORKERS" -WOLogFile - -WONoDetach YES
