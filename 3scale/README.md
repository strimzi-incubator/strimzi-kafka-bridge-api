# Requirements

* 3scale [toolbox](https://github.com/3scale/3scale_toolbox) and an HTTP client (i.e. cURL) for interacting with the 3scale API manager platform handling the service/API, the APIcast configuration and so on.
* [jq](https://stedolan.github.io/jq/) for handling JSON content during the 3scale APIcast configuration.
* TBD

# Environment variables and 3scale toolbox setup

Setting some environment variables is useful for the following command to run for the deployment.

* `REMOTE_NAME` : the name assigned to the remote address of the API manager portal that the 3scale toolbox interacts with.
* `SYSTEM_NAME` : the the name of the 3scale service/API created importing the OpenAPI specification through the 3scale toolbox.
* `TENANT` : the tenant name of the API manager portal to interact with (i.e. `https://$TENANT.3scale.net`).
* `TOKEN` : the access token provided by the API manager portal for interacting with it via 3scale toolbox or HTTP requests.

```shell
export REMOTE_NAME=strimzi-kafka-bridge
export SYSTEM_NAME=strimzi_http_bridge_for_apache_kafka
export TENANT=strimzi-kafka-bridge-admin
export TOKEN=<3scale access token>
```

Configure the remote for the 3scale toolbox.

```shell
3scale remote add $REMOTE_NAME https://$TOKEN@$TENANT.3scale.net/
```

# Configuring 3scale APIcast

## Import OpenAPI specification

The first step is about creating a new service/API in the API manager importing the HTTP - Kafka bridge OpenAPI v2 specification directly.

Update the `openapiv2.json`.

The `host` field which is the OpenShift Service name used to reach the bridge from inside the cluster.
It's going to be the "Private Base URL" for the 3scale APIcast configuration. 

```json
"host": "my-bridge-bridge-service",
```

Import the OpenAPI v2 specification with the 3scale toolbox.

```shell
3scale import openapi -d $REMOTE_NAME openapiv2.json
```

In order to make further configuration, using the 3scale toolbox or an HTTP client (i.e. cURL) for accessing to 3scale API management direclty, the "id" for the service created right now is needed.

```shell
export SERVICE_ID=$(curl -s -X GET "https://$TENANT.3scale.net/admin/api/services.json?access_token=$TOKEN" | jq ".services[] | select(.service.system_name | contains(\"$SYSTEM_NAME\")) | .service.id")
```

## Configuring the 3scale APIcast

First of all it's needed to change the deployment mode of the APIcast as "self-managed" because the gateway itself will be installed in an OpenShift cluster and will not be provided by the 3scale portal.

```shell
3scale service apply $REMOTE_NAME $SERVICE_ID -d self_managed
```

## Adding policies chain

In order to have the 3scale APIcast working with the bridge there are a few policies that has to be configured available in the `policies_config.json` file.

```shell
curl -X PUT "https://$TENANT.3scale.net/admin/api/services/$SERVICE_ID/proxy/policies.json" --data "access_token=$TOKEN" --data-urlencode policies_config@policies_config.json
```

## Promote to production

The 3scale APIcast configuration has to be promoted to production environment to be used by the gateway itself.

```shell
3scale proxy-config promote $REMOTE_NAME $SERVICE_ID
```

# Deploying 3scale APIcast on OpenShift

TBD

# Adding TLS support

TBD

# Adding authentication

TBD

# Remove

If you want to remove the 3scale service/API from the API manager.

```shell
3scale service delete $REMOTE_NAME $SERVICE_ID
```

Finally, you can remove the remote if you don't need 3scale toolbox interacting with the API manager anymore.

```shell
3scale remote remove $REMOTE_NAME
```