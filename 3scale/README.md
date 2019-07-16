Update the `openapiv2.json`.

The `host` field which is the OpenShift Service name used to reach the bridge from inside the cluster.
It's going to be the "Private Base URL" for the 3scale APIcast configuration. 

```json
"host": "my-bridge-bridge-service",
```

The `info.title` field which is going to be the 3scale service "System Name" used to identify the service itself instead of using its ID.

```json
{
  "swagger": "2.0",
  "info": {
    "title": "strimzi_http_bridge",
  ...
```

> The `SYSTEM_NAME` env var as to be set as the same value as the `info.title` field because it will be used during deployment for identifying the 3scale service/API instead of using a numeric ID.
