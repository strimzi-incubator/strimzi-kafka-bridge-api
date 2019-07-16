#!/bin/bash

. ./env.sh

# adding a remote to interact with
echo "Adding the 3scale admin portal as remote ..."
3scale remote add $REMOTE_NAME https://$TOKEN@$TENANT.3scale.net/
echo "... done"

# import OpenAPI spec
echo "Importing the OpenAPI specification ..."
3scale import openapi -d $REMOTE_NAME ./openapiv2.json
echo "... done"

# update the APIcast deployment mode to be "self managed"
echo "Set the 3scale APIcast as self-managed ..."
3scale service apply $REMOTE_NAME $SYSTEM_NAME -d self_managed
echo "... done"