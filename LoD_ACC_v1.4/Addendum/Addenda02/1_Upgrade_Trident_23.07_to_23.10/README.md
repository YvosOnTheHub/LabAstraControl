#########################################################################################
# Addenda 2: Upgrade Trident to 23.10 & enable ACP
#########################################################################################

This lab run Astra Trident v23.07.  
Let's go through the process to upgrade Trident to v23.10 The procedure can be found on this [link](https://docs.netapp.com/us-en/trident/trident-managing-k8s/upgrade-operator.html#upgrade-a-manual-installation).  

The following procedure should be used on the _helper1_ host.  

Before going through the upgrade, let's do some spring cleaning (unused packages & images), in order to free some space:
```bash
rm -f ~/tarballs/astra-control-center-*.tar.gz
rm -f ~/tarballs/trident-installer-21*.tar.gz
rm -f ~/tarballs/trident-installer-22*.tar.gz
rm -rf ~/acc/images
podman images | grep localhost | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep registry | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep docker | awk '{print $1":"$2}' | xargs podman image rm
```

Let's start by downloading the Trident package, unpack it & move the binary file:  
```bash
cd
mv trident-installer trident-installer-23.07
wget https://github.com/NetApp/trident/releases/download/v23.10.0/trident-installer-23.10.0.tar.gz
tar -xf trident-installer-23.10.0.tar.gz
cp trident-installer/tridentctl /usr/bin/
```
As Trident is installed on both RKE clsuters, you need to perform the upgrade on each environment.  
The commands _rke1_ & _rke2_ help you switch between kubeconfig files (you can check the current kubeconfnig by using the command _active_):  
```bash
rke1
helm upgrade trident ~/trident-installer/helm/trident-operator-23.10.0.tgz --namespace trident
rke2
helm upgrade trident ~/trident-installer/helm/trident-operator-23.10.0.tgz --namespace trident
```

Once the Trident operator is up-to-date, it will run through the Trident upgrade. A few minutes later, you should see something similar to:
```bash
$ kubectl get -n trident pod
NAME                                 READY   STATUS    RESTARTS   AGE
trident-controller-c97f4bc6f-l2fdc   6/6     Running   0          23m
trident-node-linux-26xxp             2/2     Running   0          23m
trident-node-linux-56dgm             2/2     Running   0          23m
trident-node-linux-hjcwn             2/2     Running   0          23m
trident-operator-7f7fd45c68-657nt    1/1     Running   0          20m

$ kubectl get tver -n trident
NAME      VERSION
trident   23.10.0
```

Let's proceed with the activation of Astra Control Provisioner.  
The first step is to locally download the ACP package, which can be found on this [link](https://mysupport.netapp.com/site/products/all/details/astra-control-center/downloads-tab). By default, it will be saved in the _Downloads_ folder on the lab jumphost.  

You then need to transfer this file from the _jumphost_ to the host where the commands need to run (_helper1_):
```bash
scp -p ~/Downloads/trident-acp-23.10.0.tar helper1:~/trident-acp-23.10.0.tar
```
Once transfered, you can upload the image to the local registy:
```bash
podman login -u registryuser -p Netapp1! registry.demo.netapp.com
podman load --input ~/trident-acp-23.10.0.tar
podman tag trident-acp:23.10.0-linux-amd64 registry.demo.netapp.com/trident-acp:23.10.0
podman push registry.demo.netapp.com/trident-acp:23.10.0
```
Finally, you can active ACP by modifying the Trident operator manually or by patching the resource (method used here).  
Remember this has to be done on both RKE clusters:  
```bash
kubectl -n trident patch torc/trident --type=json -p='[ 
        {"op":"add", "path":"/spec/enableACP", "value": true},
        {"op":"add", "path":"/spec/acpImage","value": "registry.demo.netapp.com/trident-acp:23.10.0"}
    ]'
```

After a few minutes, you should see the following:
```bash
$ kubectl get -n trident pod
NAME                                 READY   STATUS    RESTARTS   AGE
trident-controller-c97f4bc6f-l2fde   7/7     Running   0          43m
trident-node-linux-26xxp             2/2     Running   0          43m
trident-node-linux-56dgm             2/2     Running   0          43m
trident-node-linux-hjcwn             2/2     Running   0          43m
trident-operator-7f7fd45c68-657nt    1/1     Running   0          40m
```

Notice that there is a new container in the controller pod! This is the ACP image you uploaded to the local registry.  

The _all_in_one_trident_acp.sh_ script can be used to perform all these tasks.  

You can now proceed with the [ACC upgrade to 23.10](../2_Upgrade_ACC_23.07_to_23.10).