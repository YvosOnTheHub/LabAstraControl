#!/bin/bash
# SCRIPT TO RUN ON HELPER1

# to run on the jumphost once the ACC package is downloaded
# scp -p ~/Downloads/astra-control-center-23.10.0-68.tar.gz helper1:~/tarballs/

cd
echo "##########################"
echo "# Check ACC package"
echo "##########################"
FILE=~/tarballs/astra-control-center-23.10.0-68.tar.gz
if [ ! -f "$FILE" ]; then
    echo "Please download and transfer the ACC 23.10 package on the Helper1 host(folder 'tarball') before moving on."
    exit 0
fi

echo "##########################"
echo "# Pre-work"
echo "##########################"
rm -f ~/tarballs/astra-control-center-*.tar.gz
rm -f ~/tarballs/trident-installer-21*.tar.gz
rm -f ~/tarballs/trident-installer-22*.tar.gz
rm -rf ~/acc/images
podman images | grep localhost | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep registry | awk '{print $1":"$2}' | xargs podman image rm
podman images | grep docker | awk '{print $1":"$2}' | xargs podman image rm
mv ~/acc ~/acc_23.04

echo "##########################"
echo "# Untar ACC package"
echo "##########################"
tar -zxvf ~/tarballs/astra-control-center-23.10.0-68.tar.gz

echo
echo "##########################"
echo "# Add images to local repo"
echo "##########################"
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

echo
echo "#########################################"
echo "# Install the updated ACC operator"
echo "#########################################"
cd acc/manifests
cp astra_control_center_operator_deploy.yaml astra_control_center_operator_deploy.yaml.bak
sed -i s,ASTRA_IMAGE_REGISTRY,$REGISTRY/netapp/astra/$PACKAGENAME/$PACKAGEVERSION, astra_control_center_operator_deploy.yaml
sed -i s,ACCOP_HELM_INSTALLTIMEOUT,ACCOP_HELM_UPGRADETIMEOUT, astra_control_center_operator_deploy.yaml
sed -i s,'value: 5m','value: 300m', astra_control_center_operator_deploy.yaml
sed -i 's/imagePullSecrets: \[]/imagePullSecrets:/' astra_control_center_operator_deploy.yaml
sed -i '/imagePullSecrets/a \ \ \ \ \ \ - name: astra-registry-cred' astra_control_center_operator_deploy.yaml

export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
kubectl apply -f astra_control_center_operator_deploy.yaml
sleep 20

echo
frames="/ | \\ -"
PODNAME=$(kubectl -n netapp-acc-operator get pod -o name)
until [[ $(kubectl -n netapp-acc-operator get $PODNAME -o=jsonpath='{.status.conditions[?(@.type=="ContainersReady")].status}') == 'True' ]]; do
    for frame in $frames; do
    sleep 1; printf "\rwaiting for the ACC Operator to be fully ready $frame"
    done
done
sleep 30

echo
echo "############################"
echo "# Upgrade ACC"
echo "############################"
kubectl -n netapp-acc patch acc/astra --type=json -p='[ 
    {"op":"add", "path":"/spec/crds", "value":{"shouldUpgrade": true}},
    {"op":"add", "path":"/spec/additionalValues/nautilus", "value":{"startupProbe": {"failureThreshold":600, "periodSeconds": 30}}},
    {"op":"add", "path":"/spec/additionalValues/polaris-keycloak", "value":{"livenessProbe":{"initialDelaySeconds":180},"readinessProbe":{"initialDelaySeconds":180}}},    
    {"op":"replace", "path":"/spec/imageRegistry/name","value":"registry.demo.netapp.com/netapp/astra/acc/23.10.0-68"},
    {"op":"replace", "path":"/spec/astraVersion","value":"23.10.0-68"}
]'
sleep 60

echo
frames="/ | \\ -"
until [[ $(kubectl -n netapp-acc get astracontrolcenters.astra.netapp.io astra -o=jsonpath='{.status.conditions[?(@.type=="Upgrading")].reason}') == 'Complete' ]]; do
    for frame in $frames; do
       sleep 1; printf "\rwaiting for ACC upgrade to be complete $frame"
    done
done

echo
echo "############################"
echo "# upgrade finished on:"; date
echo "############################"


if [[  $(more ~/.bashrc | grep kedit | wc -l) -eq 0 ]];then
  echo
  echo "#######################################################################################################"
  echo "#"
  echo "# UPDATE BASHRC"
  echo "#"
  echo "#######################################################################################################"
  echo

  cp ~/.bashrc ~/.bashrc.bak
  cat <<EOT >> ~/.bashrc
  
alias kc='kubectl create'
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
fi
