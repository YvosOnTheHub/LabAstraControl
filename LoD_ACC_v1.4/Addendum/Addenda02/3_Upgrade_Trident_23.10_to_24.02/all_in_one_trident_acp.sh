#!/bin/bash
# SCRIPT TO RUN ON HELPER1

# to run on the jumphost once the ACP package is downloaded
# scp -p ~/Downloads/trident-acp-24.02.0.tar helper1:~/tarballs/


echo "##########################"
echo "# Check ACP package"
echo "##########################"
FILE=~/tarballs/trident-acp-24.02.0.tar
if [ ! -f "$FILE" ]; then
    echo "Please download and transfer the ACP 24.02 package on the Helper1 host before moving on."
    exit 0
fi

echo
echo "##############################"
echo "# Make way for prince Ali"
echo "##############################"
rm -f ~/tarballs/astra-control-center-*.tar.gz
rm -f ~/tarballs/trident-*.tar.gz
rm -rf ~/acc/images
podman images | grep localhost | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep registry | awk '{print $1":"$2}' | xargs podman image rm

echo
echo "############################################"
echo "# Download and unpack Trident package"
echo "############################################"
cd
mv trident-installer trident-installer-23.10
wget https://github.com/NetApp/trident/releases/download/v24.02.0/trident-installer-24.02.0.tar.gz -P ~/tarballs
tar -xf ~/tarballs/trident-installer-24.02.0.tar.gz
rm -f /usr/bin/tridentctl
cp trident-installer/tridentctl /usr/bin/

echo
echo "###############################################"
echo "# upload ACP image to the private registry"
echo "###############################################"
podman login -u registryuser -p Netapp1! registry.demo.netapp.com
podman load --input ~/tarballs/trident-acp-24.02.0.tar
podman tag trident-acp:24.02.0-linux-amd64 registry.demo.netapp.com/trident-acp:24.02.0
podman push registry.demo.netapp.com/trident-acp:24.02.0

echo
echo "####################################################"
echo "# launch the Trident upgrade on both RKE clusters"
echo "####################################################"
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
helm upgrade trident netapp-trident/trident-operator --version 100.2402.0 --set acpImage=registry.demo.netapp.com/trident-acp:24.02.0 --set enableACP=true  --namespace trident
export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
helm upgrade trident netapp-trident/trident-operator --version 100.2402.0 --set acpImage=registry.demo.netapp.com/trident-acp:24.02.0 --set enableACP=true  --namespace trident

echo
echo "############################################"
echo "# check Trident on RKE1"
echo "############################################"
export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
frames="/ | \\ -"
until [ $(kubectl -n trident get tver -o=jsonpath='{.items[0].trident_version}') = "24.02.0" ]; do
  for frame in $frames; do
    sleep 1; printf "\rwaiting for the Trident upgrade to run $frame"
  done
done
echo
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '7/7' | wc -l) -ne 5 ]; do
  for frame in $frames; do
    sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
  done
done

echo
echo "############################################"
echo "# check Trident on RKE2"
echo "############################################"
export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
frames="/ | \\ -"
until [ $(kubectl -n trident get tver -o=jsonpath='{.items[0].trident_version}') = "24.02.0" ]; do
  for frame in $frames; do
    sleep 1; printf "\rwaiting for the Trident upgrade to run $frame"
  done
done
echo
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '7/7' | wc -l) -ne 5 ]; do
  for frame in $frames; do
    sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
  done
done
