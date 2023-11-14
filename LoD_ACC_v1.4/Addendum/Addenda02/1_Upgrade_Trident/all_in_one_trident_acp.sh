#!/bin/bash
# SCRIPT TO RUN ON HELPER1

# to run on the jumphost once the ACP package is downloaded
# scp -p ~/Downloads/trident-acp-23.10.0.tar helper1:~/trident-acp-23.10.0.tar


echo "##########################"
echo "# Check ACP package"
echo "##########################"
FILE=~/trident-acp-23.10.0.tar
if [ ! -f "$FILE" ]; then
    echo "Please download and transfer the ACP 23.10 package on the Helper1 host before moving on."
    exit 0
fi

echo
echo "##############################"
echo "# Make way for prince Ali"
echo "##############################"
rm -f ~/tarballs/astra-control-center-*.tar.gz
rm -f ~/tarballs/trident-installer-21*.tar.gz
rm -f ~/tarballs/trident-installer-22*.tar.gz
rm -rf ~/acc/images
podman images | grep localhost | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep registry | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep docker | awk '{print $1":"$2}' | xargs podman image rm

echo
echo "############################################"
echo "# Download and unpack Trident package"
echo "############################################"
cd
mv trident-installer trident-installer-23.07
wget https://github.com/NetApp/trident/releases/download/v23.10.0/trident-installer-23.10.0.tar.gz
tar -xf trident-installer-23.10.0.tar.gz
cp trident-installer/tridentctl /usr/bin/

echo
echo "############################################"
echo "# Upgrade Trident on RKE1"
echo "############################################"
export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
helm upgrade trident ~/trident-installer/helm/trident-operator-23.10.0.tgz --namespace trident

frames="/ | \\ -"
until [ $(kubectl -n trident get tver -o=jsonpath='{.items[0].trident_version}') = "23.10.0" ]; do
  for frame in $frames; do
    sleep 1; printf "\rwaiting for the Trident upgrade to run $frame"
  done
done
echo
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '6/6' | wc -l) -ne 5 ]; do
  for frame in $frames; do
    sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
  done
done

echo
echo "############################################"
echo "# Upgrade Trident on RKE2"
echo "############################################"
export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
helm upgrade trident ~/trident-installer/helm/trident-operator-23.10.0.tgz --namespace trident

frames="/ | \\ -"
until [ $(kubectl -n trident get tver -o=jsonpath='{.items[0].trident_version}') = "23.10.0" ]; do
  for frame in $frames; do
    sleep 1; printf "\rwaiting for the Trident upgrade to run $frame"
  done
done
echo
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '6/6' | wc -l) -ne 5 ]; do
  for frame in $frames; do
    sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
  done
done

echo
echo "##########################"
echo "# upload ACP image"
echo "##########################"
podman login -u registryuser -p Netapp1! registry.demo.netapp.com
podman load --input ~/trident-acp-23.10.0.tar
podman tag trident-acp:23.10.0-linux-amd64 registry.demo.netapp.com/trident-acp:23.10.0
podman push registry.demo.netapp.com/trident-acp:23.10.0

echo
echo "##########################"
echo "# Enable ACP on RKE1"
echo "##########################"
export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
kubectl -n trident patch torc/trident --type=json -p='[ 
    {"op":"add", "path":"/spec/enableACP", "value": true},
    {"op":"add", "path":"/spec/acpImage","value": "registry.demo.netapp.com/trident-acp:23.10.0"}
]'

echo
echo "##########################"
echo "# Enable ACP on RKE2"
echo "##########################"
export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
kubectl -n trident patch torc/trident --type=json -p='[ 
    {"op":"add", "path":"/spec/enableACP", "value": true},
    {"op":"add", "path":"/spec/acpImage","value": "registry.demo.netapp.com/trident-acp:23.10.0"}
]'