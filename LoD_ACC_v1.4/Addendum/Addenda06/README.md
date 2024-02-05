#########################################################################################
# Addenda 6: Container images management
#########################################################################################

When running multiple appications or upgrading Astra Control a few times, you may end up with lots of container images on this lab.  
Cleaning up can be necessary in some cases, not only locally but also in the remote registry.    

_podman_ (or _docker_) can be used to manage images locally or pull/push images from/to a registry.  
However, it cannot be used to delete images remotely.  

Let's review some options.  

You first need to install _skopeo_, a tool that can be installed to interact with a remote registry.  
It is much easier to use to interact with a registry, compared to _curl_.
```bash
dnf install -y skopeo
```

Before moving forward, let's check that images can be deleted from the registry, parameter that could esily be enabled:
```bash
$ ssh -o "StrictHostKeyChecking no" root@registry.demo.netapp.com -t "podman inspect 13df | grep -A 10 Env"
               "Env": [
                    "container=podman",
                    "REGISTRY_AUTH=htpasswd",
                    "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm",
                    "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt",
                    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                    "TERM=xterm",
                    "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd",
                    "REGISTRY_HTTP_TLS_KEY=/certs/registry.key",
                    "REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true",
                    "REGISTRY_STORAGE_DELETE_ENABLED=true",
```
As you see with the last variable, deletion is enabled.  

Let's download 2 different busybox images, tag them & push them to the local registry :
```bash
podman pull busybox:1.33
podman tag busybox:1.33 registry.demo.netapp.com/busybox:1.33
podman push registry.demo.netapp.com/busybox:1.33

podman pull busybox:1.34
podman tag busybox:1.34 registry.demo.netapp.com/busybox:1.34
podman push registry.demo.netapp.com/busybox:1.34
```
We now have a container with 2 different versions & 2 different tags per version.  Let's check what we can see.  
```bash
$ podman images busybox:1.33
REPOSITORY                        TAG         IMAGE ID      CREATED      SIZE
docker.io/library/busybox         1.33        16ea53ea7c65  2 years ago  1.46 MB
registry.demo.netapp.com/busybox  1.33        16ea53ea7c65  2 years ago  1.46 MB

$ podman images busybox:1.34
REPOSITORY                        TAG         IMAGE ID      CREATED        SIZE
docker.io/library/busybox         1.34        827365c7baf1  13 months ago  5.09 MB
registry.demo.netapp.com/busybox  1.34        827365c7baf1  13 months ago  5.09 MB
```
If your registry does not have a GUI, you can use _curl_ or _skopeo_ to list the content:
```bash
$ curl -s -X GET https://registry.demo.netapp.com:5000/v2/busybox/tags/list  -ku registryuser:Netapp1!  | jq
{
  "name": "busybox",
  "tags": [
    "1.33",
    "1.34"
  ]
}

$ skopeo list-tags docker://registry.demo.netapp.com/busybox
{
    "Repository": "registry.demo.netapp.com/busybox",
    "Tags": [
        "1.33",
        "1.34"
    ]
}
```

Deleting an image from a remote registry can be achieved with both methods, though _curl_ is not very user friendy...
Let's delete the first image with _skopeo_:
```bash
$ skopeo list-tags docker://registry.demo.netapp.com/busybox
{
    "Repository": "registry.demo.netapp.com/busybox",
    "Tags": [
        "1.33",
        "1.34"
    ]
}

$ skopeo delete docker://registry.demo.netapp.com/busybox:1.33

$ skopeo list-tags docker://registry.demo.netapp.com/busybox
{
    "Repository": "registry.demo.netapp.com/busybox",
    "Tags": [
        "1.34"
    ]
}
```
Pretty straightforward !

Let's now try with curl.  
You first need to retrieve the image digest in the headers, which can them be used to delete the image.  
An image digest is a unique, immutable identifier for a container image.
```bash
$ curl -s -X GET https://registry.demo.netapp.com:5000/v2/busybox/tags/list  -ku registryuser:Netapp1!  | jq
{
  "name": "busybox",
  "tags": [
    "1.34"
  ]
}

$ curl -s -ku registryuser:Netapp1! -I -X GET https://registry.demo.netapp.com:5000/v2/busybox/manifests/1.34 -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' | awk '/^docker-content-digest/ {print $2}'
sha256:9231a8a1130e738b1c5c50014fcadb16c460826855eaa8574a18c598642e4ad9

$ curl -s -ku registryuser:Netapp1! -X DELETE https://registry.demo.netapp.com:5000/v2/busybox/manifests/sha256:9231a8a1130e738b1c5c50014fcadb16c460826855eaa8574a18c598642e4ad9

$ curl -s -X GET https://registry.demo.netapp.com:5000/v2/busybox/tags/list  -ku registryuser:Netapp1!  | jq
{
  "name": "busybox",
  "tags": null
}
```
I find the _curl_ to be more error prone... However, it works out of the box.