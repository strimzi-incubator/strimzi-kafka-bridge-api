Update the `openapiv2.json`.

The `host` field which is the OpenShift Service name used to reach the bridge from inside the cluster.
It's going to be the "Private Base URL" for the 3scale APIcast configuration. 

```json
"host": "my-bridge-bridge-service",
```