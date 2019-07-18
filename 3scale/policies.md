# 3scale APIcast policies

The APIcast policies provides a mechanism to modify how the gateway operates.
3scale provides a bunch of standard policies that can be applied to the gateway configuration and enabled/disabled when needed.

The `policies_config.json` provides a sample configuration of the following policies:

* Anonymous access
* Header modification
* Routing
* URL rewriting

## Anonymous access

This policy can be used for exposing the service without authentication.
It contains default credentials to use when the HTTP client doesn't provide them (as anonymous).
It's not mandatory and can be disabled or removed if the authentication is needed.

## Header modification

This policy allows to modify existing headers or adding new ones to requests or responses going throug the gateway.
This 3scale - HTTP Kafka bridge integration provides a policy for adding a few headers to every request flowing from the HTTP client to the bridge through the gateway.
The need for this policy is related to how the bridge behaves when it receives a request for creating a new consumer.
In this specific case, it returns a JSON payload containing a `base_uri` field with the URI that the consumer has to use for all the subsequent requests (subscribe, getting records, seeking and so on).
For example:

```json
{
    "instance_id": "consumer-1",
    "base_uri":"http://my-bridge:8080/consumers/my-group/instances/consumer1"
}
```

Of course, when using the 3scale APIcast in front of the bridge, the URI doesn't have to contain the address of the bridge which is behind the gateway but the gateway hostname; clients have to connect to the gateway and not to the bridge directly.

Using the header modification policies, a few headers are added to the request coming from the HTTP client: the `Forwarded` header or the combination of `X-Forwarded-Host` and `X-Forwarded-Proto` headers.
In this way, when building the `base_uri` to return to the consumer, the bridge use the gateway hostname so that the HTTP client will continue to send all the subsequent requests to the gateway and not to the bridge directly.
For example, having `Forwarded: host=my-gateway:80;proto=http`, the bridge will be able to deliver the following to the consumer.

```json
{
    "instance_id": "consumer-1",
    "base_uri":"http://my-gateway:80/consumers/my-group/instances/consumer1"
}
```

Another header is used to bring the original path contained in the HTTP request coming from the client to the gateway; it's the `X-Forwarded-Path`.
Its usage is strictly related to the routing policy when the gateway is backing more than one bridge instances.

## Routing

From the consumer point of view, the bridge is "stateful" in the sense that when a new consumer is created, its information are saved in the bridge instance where the request was sent.
It means that every subsequent request (i.e. subscribe, getting messages, seeking) has to be send to the same bridge instance where the consumer was created.
For this reason, on OpenShift, it's not possible to have just a single `Service` backing the bridge `Deployment` with more replicas leveraging its round-robin mechanism.
For scaling the bridge, the only way is to have different `Deployment`(s) with just one replica, each one with the related `Service`.

When a 3scale gateway it put in front of more bridge instances, it's needed to use a routing policy in order to have the gateway forwarding the request to a specific bridge instance.

The provided `policies_config.json` file show an example of routing to 3 bridge instances.
Using Strimzi, each bridge is named as `my-bridge-X` (with X as 1, 2 and 3) so the related `Service`(s) are `my-bridge-X-bridge-service`.
Of course, you can chose the name for each bridge instance during its deployment using Strimzi in the `KafkaBridge` custom resource.

The routing to the right bridge instance is done based on the bridge name which has to be in the path request (so the usage of `X-Forwarded-Path` as mentioned in the previous paragraph).
For example, each request from a consumer to 

`http://my-gateway:80/my-bridge-1/consumers/my-group/instances/consumer1` 

is forwarded to 

`http://my-bridge-1-bridge-service:8080/consumers/my-group/instances/consumer1`

Please note that the bridge name is not in the path anymore, and it's related to the usage of the following URL rewriting policy.

## URL rewriting

This policy allows to rewrite the URL of the request coming from the HTTP client to the request that the gateway sends to the bridge.
It's needed together with the routing policy because its purpose is to remove the bridge name in the path request, because it's not part of the endpoints exposed by the bridge itself (describe in the related OpenAPI specification).