#!/bin/bash

. ./env.sh

# delete the 3scale service/API
3scale service delete $REMOTE_NAME $SYSTEM_NAME

# remove the remote
3scale remote remove $REMOTE_NAME