#########################################################################################
# Addenda 2: Upgrade Trident & ACP to 24.02
#########################################################################################

This chapter expects you to have already gone through the 2 previous ones (upgrade from 23.07 to 23.10) 
The procedure to upgrade Trident to 24.02 can be found on this [link](https://docs.netapp.com/us-en/trident/trident-managing-k8s/upgrade-operator.html#upgrade-a-manual-installation).  

Both Trident & ACP will be upgraded through the same Helm command.  

The following procedure should be used on the _helper1_ host.  

Before going through the upgrade, let's do some spring cleaning (unused packages & images), in order to free some space:
```bash
rm -f ~/tarballs/astra-control-center-*.tar.gz
rm -f ~/tarballs/trident-*.tar.gz
rm -rf ~/acc/images
podman images | grep localhost | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep registry | awk '{print $1":"$2}' | xargs podman image rm
```

Let's start by downloading the Trident package, unpack it & move the binary file:  
```bash
cd
mv trident-installer trident-installer-23.10
wget https://github.com/NetApp/trident/releases/download/v24.02.0/trident-installer-24.02.0.tar.gz -P ~/tarballs
tar -xf ~/tarballs/trident-installer-24.02.0.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/
```

Let's proceed with the download of Astra Control Provisioner.  
The first step is to locally download the ACP package, which can be found on this [link](https://mysupport.netapp.com/site/products/all/details/astra-control-center/downloads-tab). By default, it will be saved in the _Downloads_ folder on the lab jumphost.  

You then need to transfer this file from the _jumphost_ to the host where the commands need to run (_helper1_):
```bash
scp -p ~/Downloads/trident-acp-24.02.0.tar helper1:~/tarballs/
```
Once transfered, you can upload the image to the local registy:
```bash
podman login -u registryuser -p Netapp1! registry.demo.netapp.com
podman load --input ~/tarballs/trident-acp-24.02.0.tar
podman tag trident-acp:24.02.0-linux-amd64 registry.demo.netapp.com/trident-acp:24.02.0
podman push registry.demo.netapp.com/trident-acp:24.02.0
```

Now, as Trident is installed on both RKE clsuters, you need to perform the upgrade on each environment.  
The commands _rke1_ & _rke2_ help you switch between kubeconfig files (you can check the current kubeconfnig by using the command _active_):  
```bash
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart    
rke1
helm upgrade trident netapp-trident/trident-operator --version 100.2402.0 --set acpImage=registry.demo.netapp.com/trident-acp:24.02.0 --set enableACP=true  --namespace trident
rke2
helm upgrade trident netapp-trident/trident-operator --version 100.2402.0 --set acpImage=registry.demo.netapp.com/trident-acp:24.02.0 --set enableACP=true  --namespace trident
```

Once the Trident operator is up-to-date, it will run through the Trident upgrade (it takes about 3 minutes to start). A few minutes later, you should see something similar to:
```bash
$ kubectl get -n trident pod
NAME                                 READY   STATUS    RESTARTS   AGE
trident-controller-c97f4bc6f-l2fdc   7/7     Running   0          23m
trident-node-linux-26xxp             2/2     Running   0          23m
trident-node-linux-56dgm             2/2     Running   0          23m
trident-node-linux-hjcwn             2/2     Running   0          23m
trident-operator-7f7fd45c68-657nt    1/1     Running   0          20m

$ kubectl get tver -n trident
NAME      VERSION
trident   24.02.0
```

The _all_in_one_trident_acp.sh_ script can be used to perform all these tasks.  

You can now proceed with the [ACC upgrade to 24.02](../4_Upgrade_ACC_23.10_to_24.02).