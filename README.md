# Kubernetes Ingress Nginx Plugins

## Plugins List
1. hello_world - https://github.com/kubernetes/ingress-nginx/tree/master/rootfs/etc/nginx/lua/plugins/hello_world


## Adding Custom Plugin to Ingress-Nginx in Kubernetes

Once you have created your [Custom Lua Plugin](https://github.com/kubernetes/ingress-nginx/tree/master/rootfs/etc/nginx/lua/plugins) and want to add it to your Ingress Nginx within Kubernetes, you have two options

* Mount a volume contaning custom plugin code
* Build your own custom docker image containing plugin

### Mouting a volume containing custom plugin code  

Plugin code can be cloned from Github, Gitlab, S3, etc. through an [Init Container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) and then mounted to the main container running Nginx. We shall clone the repo using [git-sync](https://github.com/kubernetes/git-sync). We shall be deploying Ingress-Ngnix on Kubernetes using [Helm Chart](https://kubernetes.github.io/ingress-nginx/deploy/#using-helm).

```
ingress-nginx:
  controller:respository
    extraVolumes:
    - name: lua-plugins
      emptyDir: {}
    extraInitContainers:
    - name: init-clone-plugins
      image: k8s.gcr.io/git-sync/git-sync:v3.1.7
      env:
      - name: GIT_SYNC_REPO
        value: "https://github.com/vishaltak/ingress-nginx-plugins"
      - name: GIT_SYNC_BRANCH
        value: "master"
      - name: GIT_SYNC_ROOT
        value: "/lua_plugins"
      - name: GIT_SYNC_DEST
        value: "custom"
      - name: GIT_SYNC_ONE_TIME
        value: "true"
      - name: GIT_SYNC_DEPTH
        value: "1"
      volumeMounts:
      - name: lua-plugins
        mountPath: /lua_plugins
```

When using private repositories, add service account credentials as environment variables(`GIT_SYNC_USERNAME` and `GIT_SYNC_PASSWORD`) or SSH environment variables(`GIT_SYNC_SSH` and `GIT_SSH_KEY_FILE`)

Use `GIT_SYNC_BRANCH` for development and `GIT_SYNC_REV` for production deployments to pin the code to a commit and maintain immutable-like consistent behaviour across Pod restarts.

Once the Init Container has run successfully, we need to mount the `${GIT_SYNC_DEST}` sub-path of the volume at location `/etc/nginx/lua/plugins` within the main container running Nginx.

```
ingress-nginx:
  controller:
    extraVolumeMounts:
    - name: lua-plugins
      mountPath: /etc/nginx/lua/plugins
      subPath: custom
```

By default, Nginx loads only those extra environment variables which are explicitly specified. If your plugin requires certain extra envrionment variables, you need to specify the extra envrionment variables to be loaded into the [main-snippet](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#main-snippet) of Nginx configuration.

```
ingress-nginx:
  controller:
    extraEnvs:
    - name: ENV_NAME_1
      value: "ENV_VALUE_1"
    - name: ENV_NAME_2
      value: "ENV_VALUE_2"
    config:
      main-snippet: |
        env ENV_VALUE_1;
        env ENV_VALUE_2;
```

To load the Lua plugin, we need to specify a comma-separated list of the order of loading Custom Lua Plugins.

```
ingress-nginx:
  controller:
    config:
      plugins: "hello_world"
```

In summary, the Helm values will be

```
ingress-nginx:
  controller:respository
    extraVolumes:
    - name: lua-plugins
      emptyDir: {}
    extraInitContainers:
    - name: init-clone-plugins
      image: k8s.gcr.io/git-sync/git-sync:v3.1.7
      env:
      - name: GIT_SYNC_REPO
        value: "https://github.com/vishaltak/ingress-nginx-plugins"
      - name: GIT_SYNC_BRANCH
        value: "master"
      - name: GIT_SYNC_ROOT
        value: "/lua_plugins"
      - name: GIT_SYNC_DEST
        value: "custom"
      - name: GIT_SYNC_ONE_TIME
        value: "true"
      - name: GIT_SYNC_DEPTH
        value: "1"
      volumeMounts:
      - name: lua-plugins
        mountPath: /lua_plugins
    extraVolumeMounts:
    - name: lua-plugins
      mountPath: /etc/nginx/lua/plugins
      subPath: custom
    extraEnvs:
    - name: ENV_NAME_1
      value: "ENV_VALUE_1"
    - name: ENV_NAME_2
      value: "ENV_VALUE_2"
    config:
      main-snippet: |
        env ENV_VALUE_1;
        env ENV_VALUE_2;
      plugins: "hello_world"
```

The redacted Deployment is

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: ingress-nginx-controller
spec:
  template:
    spec:
      initContainers:
      - name: init-clone-plugins
        image: k8s.gcr.io/git-sync/git-sync:v3.1.7
        env:
        - name: GIT_SYNC_REPO
          value: "https://github.com/vishaltak/ingress-nginx-plugins"
        - name: GIT_SYNC_BRANCH
          value: "master"
        - name: GIT_SYNC_ROOT
          value: "/lua_plugins"
        - name: GIT_SYNC_DEST
          value: "custom"
        - name: GIT_SYNC_ONE_TIME
          value: "true"
        - name: GIT_SYNC_DEPTH
          value: "1"
        volumeMounts:
        ...
        - mountPath: /lua_plugins
          name: lua-plugins
        ...
      containers:
      - name: controller
        image: us.gcr.io/k8s-artifacts-prod/ingress-nginx/controller:v0.34.1@sha256:0e072dddd1f7f8fc8909a2ca6f65e76c5f0d2fcfb8be47935ae3457e8bbceb20
        env:
        ...
        - name: ENV_NAME_1
          value: ENV_VALUE_1
        - name: ENV_NAME_2
          value: ENV_VALUE_2
        volumeMounts:
        ...
        - mountPath: /etc/nginx/lua/plugins
          name: lua-plugins
          subPath: custom
        ...
      volumes:
      ...
      - emptyDir: {}
        name: lua-plugins
```

The redacted ConfigMap is

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
data:
  ...
  main-snippet: |
    env ENV_NAME_1;
    env ENV_NAME_2;
  plugins: hello_world
```
