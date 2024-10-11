[3scaledoc]: https://docs.redhat.com/en/documentation/red_hat_3scale_api_management "3scale documentation"

# Requirements

* Familiarity with 3scale components.
* Strimzi and Kafka are deployed. 
* Kafka Bridge is deployed. 

For 3scale deployment to Kubernetes:

* The installation requires `cluster-admin` access, such as `system:admin`.
* The following JSON files are required:
    * Kafka Bridge [openapi.json](openapi.json) v3.
    * Header modification and routing policies for Kafka Bridge: [policies_config.json](policies_config.json).

# Procedure

1. Set up 3scale API Management as outlined in the [3scale documentation][3scaledoc].

    1.1. Install 3scale API Manager and APIcast using the 3scale operators.

    Before deploying API Manager, update the `wildcardDomain` property of the `APIManager` custom resource to match your Kubernetes cluster’s domain.

    The domain is used in the URL to access the 3scale Admin Portal (`http[s]://<authentication_token>@3scale-admin.<cluster_domain>`). 

    1.2 Verify 3scale deployment by checking the status of the `APIManager` custom resource.

2. Authorize 3scale API Manager to discover Kafka Bridge:

    ````
    oc adm policy add-cluster-role-to-user view system:serviceaccount:<my_bridge_namespace>:amp
    ````

    This command grants the API Manager (`amp`) read access (`view`) to Kafka Bridge resources in the specified namespace (`<my_bridge_namespace>`).

3. Ensure the Cluster Operator deployment has the required labels and annotations for 3scale discovery:

    ```
    #...
    env:
    - name: STRIMZI_CUSTOM_KAFKA_BRIDGE_SERVICE_LABELS
        value: |
        discovery.3scale.net=true
    - name: STRIMZI_CUSTOM_KAFKA_BRIDGE_SERVICE_ANNOTATIONS
        value: |
        discovery.3scale.net/scheme=http
        discovery.3scale.net/port=8080
        discovery.3scale.net/path=/
        discovery.3scale.net/description-path=/openapi/v3
    #...
    ````
    
    **NOTE:** The `/openapi` endpoint will represent OpenAPI v3 once support for OpenAPI v2 is removed from the Kafka Bridge. At that time, the `/openapi/v3` endpoint will be removed.

    If necessary, update these properties.

4. From the 3scale Admin Portal, import the Kafka Bridge API service from Kubernetes as outlined in the [3scale documentation][3scaledoc].

5. Add the `servers` property to the OpenAPI specification (JSON file) to reference the base Kafka Bridge service URL:

    **Example reference to the Kafka Bridge service URL**
    ````
    {
        "openapi": "3.0.0",
        "info": {
        "title": "Kafka Bridge API Reference",
        "description": "The Kafka Bridge provides a REST API 
            for integrating HTTP based client applications with 
            a Kafka cluster. You can use the API to create and 
            manage consumers and send and receive records over 
            HTTP rather than the native Kafka protocol. ",
            "version": "0.1.0"
        },
        "servers": [
        {
            "url": "https://my-bridge-bridge-service.my-project.svc.cluster.local:8080"
        }
        ],
        "paths": {
    ````

    Make sure the `servers` URL includes the following:

    * Kafka Bridge name (`my-bridge`)
    * Project name (`my-project`)
    * Port for the Kafka Bridge (`8080`)

6. Import the Kafka Bridge OpenAPI specification by creating an `OpenAPI` custom resource.

    When creating the `OpenAPI` custom resource, the 3scale operator automatically creates a 3scale `Product` custom resource, which includes a service ID.  

7. Update the `Product` custom resource by importing the Kafka Bridge routing policies (`policies_config.json`).

8. From the 3scale Admin Portal, check that the endpoints and policies for the Kafka Bridge service have loaded.

9. Update the `Product` custom resource to set up an application plan and application.

    The application is necessary to obtain a user key for authentication.

10. (For production) Promote the product's APIcast configuration by creating a `ProxyConfigPromote` custom resource.

11. Verify API access to Kafka Bridge through the APIcast gateway using a consumer creation call and the user key generated for the application.

    For example:

    ````
    https//my-project-my-bridge-bridge-service-3scale-apicast-staging.example.com:443/consumers/my-group?user_key=3dfc188650101010ecd7fdc56098ce95
    ````

    If the response payload is returned from Kafka Bridge, the consumer was successfully created.

    ````
    {
    "instance_id": "consumer1",
    "base uri": "https//my-project-my-bridge-bridge-service-3scale-apicast-staging.example.com:443/consumers/my-group/instances/consumer1"
    }
    ````

    The base URI is the address that the client will use for subsequent requests.