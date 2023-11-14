#########################################################################################
# Addenda 2: Upgrade Astra Control to v23.10
#########################################################################################

The procedure can be found on this [link](https://docs.netapp.com/us-en/astra-control-center/use/upgrade-acc.html).  

The first step would be to locally download the Astra Control package, which can be found on this [link](https://mysupport.netapp.com/site/products/all/details/astra-control-center/downloads-tab). By default, it will be saved in the _Downloads_ folder on the lab jumphost.  

You then need to transfer this file from the _jumphost_ to the host where the commands need to run (_helper1_), in the _tarballs_ folder:
```bash
scp -p ~/Downloads/astra-control-center-23.10.0-68.tar.gz helper1:~/tarballs/
```

You can now go through each step manually, or use the _all_in_one.sh_ script available on this github repository.  
The script must run on the _helper1_ host.  

If you have not gone through the [Trident upgrade](../1_Upgrade_Trident_23.07_to_23.10), you first need to free some space:
```bash
rm -f ~/tarballs/astra-control-center-*.tar.gz
rm -f ~/tarballs/trident-installer-21*.tar.gz
rm -f ~/tarballs/trident-installer-22*.tar.gz
rm -rf ~/acc/images
podman images | grep localhost | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep registry | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep docker | awk '{print $1":"$2}' | xargs podman image rm
```

Let' start by by unpacking the ACC package:
```bash
cd
tar -zxvf ~/tarballs/astra-control-center-23.10.0-68.tar.gz
```

The installation process will use the lab private registry for ACC's container images. Let's upload them (copy and paste the whole block):
```bash
podman login -u registryuser -p Netapp1! registry.demo.netapp.com

export REGISTRY=registry.demo.netapp.com
export PACKAGENAME=acc
export PACKAGEVERSION=23.10.0-68
export DIRECTORYNAME=acc

for astraImageFile in $(ls ${DIRECTORYNAME}/images/*.tar) ; do
  # Load to local cache
  astraImage=$(podman load --input ${astraImageFile} | sed 's/Loaded image: //')
  # Remove path and keep imageName.
  astraImageNoPath=$(echo ${astraImage} | sed 's:.*/::')
  # Tag with local image repo.
  podman tag ${astraImage} ${REGISTRY}/netapp/astra/${PACKAGENAME}/${PACKAGEVERSION}/${astraImageNoPath}
  # Push to the local repo.
  podman push ${REGISTRY}/netapp/astra/${PACKAGENAME}/${PACKAGEVERSION}/${astraImageNoPath}
done
```

The next step is about customizing the updated ACC Operator.  
For the update to be successful, the most important parameters to modify are:
- image registry
- image registry secret

```bash
cd acc/manifests
cp astra_control_center_operator_deploy.yaml astra_control_center_operator_deploy.yaml.bak

sed -i s,ASTRA_IMAGE_REGISTRY,$REGISTRY/netapp/astra/$PACKAGENAME/$PACKAGEVERSION, astra_control_center_operator_deploy.yaml
sed -i s,ACCOP_HELM_INSTALLTIMEOUT,ACCOP_HELM_UPGRADETIMEOUT, astra_control_center_operator_deploy.yaml
sed -i s,'value: 5m','value: 300m', astra_control_center_operator_deploy.yaml
sed -i 's/imagePullSecrets: \[]/imagePullSecrets:/' astra_control_center_operator_deploy.yaml
sed -i '/imagePullSecrets/a \ \ \ \ \ \ - name: astra-registry-cred' astra_control_center_operator_deploy.yaml
```

The operator can now be upgraded:
```bash
$ rke1
$ kubectl apply -f astra_control_center_operator_deploy.yaml
namespace/netapp-acc-operator unchanged
customresourcedefinition.apiextensions.k8s.io/astracontrolcenters.astra.netapp.io configured
role.rbac.authorization.k8s.io/acc-operator-leader-election-role unchanged
clusterrole.rbac.authorization.k8s.io/acc-operator-manager-role configured
clusterrole.rbac.authorization.k8s.io/acc-operator-metrics-reader unchanged
clusterrole.rbac.authorization.k8s.io/acc-operator-proxy-role unchanged
rolebinding.rbac.authorization.k8s.io/acc-operator-leader-election-rolebinding unchanged
clusterrolebinding.rbac.authorization.k8s.io/acc-operator-manager-rolebinding configured
clusterrolebinding.rbac.authorization.k8s.io/acc-operator-proxy-rolebinding unchanged
configmap/acc-operator-manager-config unchanged
service/acc-operator-controller-manager-metrics-service unchanged
deployment.apps/acc-operator-controller-manager configured
```

Within a minute, the new operator should be up&running. Let's verify its state & readiness (which should indicate _True_):
```bash
$ kubectl -n netapp-acc-operator get pod
NAME                                               READY   STATUS    RESTARTS   AGE
acc-operator-controller-manager-5f68b5c49b-r76jt   2/2     Running   0           1m

$ export PODNAME=$(kubectl -n netapp-acc-operator get pod -o name)
$ kubectl -n netapp-acc-operator get $PODNAME -o=jsonpath='{.status.conditions[?(@.type=="ContainersReady")].status}'; echo
True
```

We can now proceed with the upgrade of Astra Control Center.  
This can be achieved by editing the ACC CR, or by simply patching it, method we will use here:  
```bash
$ kubectl -n netapp-acc patch acc/astra --type=json -p='[ 
    {"op":"add", "path":"/spec/crds", "value":{"shouldUpgrade": true}},
    {"op":"add", "path":"/spec/additionalValues/nautilus", "value":{"startupProbe": {"failureThreshold":600, "periodSeconds": 30}}},
    {"op":"add", "path":"/spec/additionalValues/polaris-keycloak", "value":{"livenessProbe":{"initialDelaySeconds":180},"readinessProbe":{"initialDelaySeconds":180}}},    
    {"op":"replace", "path":"/spec/imageRegistry/name","value":"registry.demo.netapp.com/netapp/astra/acc/23.10.0-68"},
    {"op":"replace", "path":"/spec/astraVersion","value":"23.10.0-68"}
]'
astracontrolcenter.astra.netapp.io/astra patched
```

This upgrade should take about 30 minutes, after what we can check if all went well (we expect the value _Complete_):  
```bash
$ kubectl -n netapp-acc get astracontrolcenters.astra.netapp.io astra -o=jsonpath='{.status.conditions[?(@.type=="Upgrading")].reason}'; echo
Complete
```

Tadaaa! You can now reconnect to the Astra Control GUI, using the same password as before (NetApp1!).  
