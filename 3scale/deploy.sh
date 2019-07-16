#!/bin/bash

. ./env.sh

# adding a remote to interact with
3scale remote add $REMOTE_NAME https://$TOKEN@$TENANT.3scale.net/

# import OpenAPI spec
3scale import openapi -d $REMOTE_NAME ./openapiv2.json

# update the APIcast deployment mode to be "self managed"
3scale service apply $REMOTE_NAME $SYSTEM_NAME -d self_managed