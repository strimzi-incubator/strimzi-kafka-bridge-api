# Requirements

* 3scale [toolbox](https://github.com/3scale/3scale_toolbox) and an HTTP client (i.e. cURL) for interacting with the 3scale API manager platform handling the service/API, the APIcast configuration and so on.
* [jq](https://stedolan.github.io/jq/) for handling JSON content during the 3scale APIcast configuration.
* TBD

# Deploying 3scale API management

Starting OpenShift with more resources due to 3scale API management.
In case of `minishift`, it needs at least 4 cpus and 8 GB of RAM.

```shell
minishift start --cpus 4 --memory 8GB
```

Login as a user with admin rights, in order to enable wildcard routes and for Strimzi in order to create the CRDs.

```shell
oc login -u system:admin
```

Enable wildcard routes on OpenShift.

> More info [here](https://access.redhat.com/solutions/3697871) and [here](https://access.redhat.com/documentation/en-us/openshift_container_platform/3.9/html/installation_and_configuration/setting-up-a-router#using-wildcard-routes)

```shell
oc project default

oc adm router --replicas=0
oc set env dc/router ROUTER_ALLOW_WILDCARD_ROUTES=true
oc scale dc/router --replicas=1

oc project myproject
```

Deploy the 3scale API management using the template provided by the `amp.yml` file.
It's a hacked version of this [one](https://raw.githubusercontent.com/3scale/3scale-amp-openshift-templates/master/amp/amp.yml) for using the latest apicast gateway with the fixes needed for having the integration working.

```shell
oc new-app -f amp.yml --param WILDCARD_DOMAIN=example.com --param WILDCARD_POLICY=Subdomain --param ADMIN_PASSWORD=admin --param ADMIN_ACCESS_TOKEN=mytoken
```

Grant 3scale discovery to view the services in order to discover them for the creation.

```shell
oc adm policy add-cluster-role-to-user view system:serviceaccount:myproject:default
```

If running on `minishift` and you want to access the 3scale admin portal, the gateway and all the other stuff from outside, it's needed to update the `/etc/hosts` accordingly, for example:

```shell
192.168.42.233 api-3scale-apicast-production.example.com
192.168.42.233 apicast-wildcard.example.com
192.168.42.233 api-3scale-apicast-staging.example.com
192.168.42.233 3scale.example.com
192.168.42.233 master.example.com
192.168.42.233 3scale-admin.example.com
192.168.42.233 backend-3scale.example.com
192.168.42.233 myproject-my-bridge-bridge-service-3scale-apicast-staging.example.com
192.168.42.233 myproject-my-bridge-bridge-service-3scale-apicast-production.example.com
```

# Deploying Strimzi, the Apache Kafka cluster and the bridge

The cluster operator has to be enabled to set 3scale labels and annotations on the HTTP bridge service so that it is discoverable by the 3scale service discovery.
To do so, check that the following environment variables are set in the cluster operator deployment:

```yaml
...
env:
- name: STRIMZI_CUSTOM_KAFKA_BRIDGE_SERVICE_LABELS
    value: |
    discovery.3scale.net=true
- name: STRIMZI_CUSTOM_KAFKA_BRIDGE_SERVICE_ANNOTATIONS
    value: |
    discovery.3scale.net/scheme=http
    discovery.3scale.net/port=8080
    discovery.3scale.net/path=/
    discovery.3scale.net/description-path=/openapi
...
```

Just run the following command from the Strimzi release folder.

```shell
oc apply -f install/cluster-operator
oc apply -f examples/kafka/kafka-ephemeral.yaml
oc apply -f examples/kafka-bridge/kafka-bridge.yaml
```

# Environment variables and 3scale toolbox setup

Setting some environment variables is useful for the following command to run for the deployment.

* `REMOTE_NAME` : the name assigned to the remote address of the API manager portal that the 3scale toolbox interacts with.
* `SYSTEM_NAME` : the the name of the 3scale service/API created importing the OpenAPI specification through the 3scale toolbox.
* `TENANT` : the tenant name of the API manager portal to interact with (i.e. `https://$TENANT.3scale.net`).
* `TOKEN` : the access token provided by the API manager portal for interacting with it via 3scale toolbox or HTTP requests.
* `PORTAL_ENDPOINT`: the 3scale portal endpoint running the API manager to interact with

```shell
export REMOTE_NAME=strimzi-kafka-bridge
export SYSTEM_NAME=myproject-my-bridge-bridge-service
export TENANT=3scale-admin
export PORTAL_ENDPOINT=$TENANT.example.com
export TOKEN=<3scale access token>
```

Configure the remote for the 3scale toolbox.

```shell
3scale remote add -k $REMOTE_NAME https://$TOKEN@$PORTAL_ENDPOINT/
```

# Adding bridge API

Access to the 3scale admin portal (i.e. 3scale-admin.example.com) and go to "New API" -> "Improt from OpenShift".
The bridge service should be there, ready to be imported.

Due to service discovery not importing the methods, we have to update the service using the 3scale toolbox.
Before that, update the "host" field with the current Private Base URL (my-bridge-bridge-service.myproject.svc.cluster.local:8080)

```shell
3scale import openapi -k -d $REMOTE_NAME openapiv2.json -t myproject-my-bridge-bridge-service
```

In order to make further configuration, using the 3scale toolbox or an HTTP client (i.e. cURL) for accessing to 3scale API management direclty, the "id" for the service created right now is needed.

```shell
export SERVICE_ID=$(curl -k -s -X GET "https://$PORTAL_ENDPOINT/admin/api/services.json?access_token=$TOKEN" | jq ".services[] | select(.service.system_name | contains(\"$SYSTEM_NAME\")) | .service.id")
```

Last step is about importing the policies.
It's not supported by the 3scale toolbox so using just HTTP call via `curl`.

```shell
curl -k -X PUT "https://$PORTAL_ENDPOINT/admin/api/services/$SERVICE_ID/proxy/policies.json" --data "access_token=$TOKEN" --data-urlencode policies_config@policies_config.json
```

# Application plan and application

For interacting with the API, it's needed to create an application plan first.

So go to "Applications" -> "Create Application Plan"

After that, a new application has to be created in order to get a User Key that will be used as the default authentication mechanism.

So go to "Audience" -> "Developer" -> "Applications" -> "Create Application"

If you want to use the production gateway you have to promote the configuration otherwise you can just use the staging one.

```shell
The 3scale APIcast configuration has to be promoted to production environment to be used by the gateway itself.

```shell
3scale proxy-config promote $REMOTE_NAME $SERVICE_ID
```