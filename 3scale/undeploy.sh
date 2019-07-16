#!/bin/bash

. ./env.sh

# delete the 3scale service/API
echo "Deleting $SYSTEM_NAME 3scale service/API ..."
3scale service delete $REMOTE_NAME $SYSTEM_NAME
echo "... done"

# remove the remote
echo "Removing 3scale admin portal as remote ..."
3scale remote remove $REMOTE_NAME
echo "... done"