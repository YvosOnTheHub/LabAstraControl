#!/bin/bash
# SCRIPT TO RUN ON HELPER1

# to run on the jumphost once the ACC package is downloaded
# scp -p ~/Downloads/astra-control-center-23.04.0-22.tar.gz helper1:~/tarballs/


echo "##########################"
echo "# Check ACC package"
echo "##########################"
FILE=~/tarballs/astra-control-center-23.04.0-22.tar.gz
if [ ! -f "$FILE" ]; then
    echo "Please download and transfer the ACC 23.04 package on the Helper1 host(folder 'tarball') before moving on."
    exit 0
fi

echo "##########################"
echo "# Pre-work"
echo "##########################"
rm -f ~/tarballs/astra-control-center-21*.tar.gz
rm -f ~/tarballs/astra-control-center-22*.tar.gz
rm -f ~/tarballs/trident*.tar.gz
rm -rf ~/acc/images
mv ~/acc ~/acc_22.11

echo "##########################"
echo "# Untar ACC package"
echo "##########################"
tar -zxvf ~/tarballs/astra-control-center-23.04.0-22.tar.gz

echo
echo "##########################"
echo "# add images to local repo"
echo "##########################"
podman login -u registryuser -p Netapp1! registry.demo.netapp.com

export REGISTRY=registry.demo.netapp.com
export PACKAGENAME=acc
export PACKAGEVERSION=23.04.0-22
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
echo "############################"
echo "# install the updated ACC operator"
echo "############################"
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
echo "# upgrade ACC"
echo "############################"

kubectl -n netapp-acc patch acc/astra --type=json -p='[ 
    {"op":"add", "path":"/spec/crds", "value":{"shouldUpgrade": true}},
    {"op":"replace", "path":"/spec/imageRegistry/name","value":"registry.demo.netapp.com/netapp/astra/acc/23.04.0-22"},
    {"op":"replace", "path":"/spec/astraVersion","value":"23.04.0-22"}
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
echo "######################################"
echo "# Remove old images"
echo "######################################"

podman images | grep registry.demo.netapp.com/astra | awk '{print $1":"$2}' | xargs podman image rm

podman image rm localhost/enterprise-helm-repo:22.11.0-82
podman image rm localhost/nautilus:1.4.43
podman image rm localhost/storage-provider:1.4.2
podman image rm localhost/cloud-extension:1.4.9
podman image rm localhost/task-service:1.1.4
podman image rm localhost/packages:0.2.3
podman image rm localhost/identity:1.4.3
podman image rm localhost/composite-volume:1.4.2
podman image rm localhost/composite-compute:1.4.5
podman image rm localhost/asup:1.4.2
podman image rm localhost/tenancy:1.4.2
podman image rm localhost/features:1.4.3
podman image rm localhost/entitlement:1.4.2
podman image rm localhost/certificates:1.2.2
podman image rm localhost/activity:1.4.2
podman image rm localhost/openapi:1.4.6
podman image rm localhost/krakend:1.4.3
podman image rm localhost/keycloak-operator:0.2.3
podman image rm localhost/bucketservice:1.4.1
podman image rm localhost/acc-operator:22.11.5
podman image rm localhost/polaris-ui:1.4.14
podman image rm localhost/graphql-server:1.4.4
podman image rm localhost/vault-controller:1.4.1
podman image rm localhost/telemetry-service:1.4.1
podman image rm localhost/trident-svc:1.4.6
podman image rm localhost/storage-backend-metrics:1.4.1
podman image rm localhost/public-metrics:1.4.1
podman image rm localhost/metrics-facade:0.2.1
podman image rm localhost/license:1.4.2
podman image rm localhost/credentials:1.4.2
podman image rm localhost/cloud-insights-service:1.4.2
podman image rm localhost/authentication:1.4.1
podman image rm localhost/api-token-authentication:0.4.1
podman image rm localhost/cert-manager-controller:v1.10.0
podman image rm localhost/cert-manager-webhook:v1.10.0
podman image rm localhost/cert-manager-cainjector:v1.10.0
podman image rm localhost/cert-manager-ctl:v1.10.0
podman image rm localhost/login-ui:1.4.0
podman image rm localhost/netapp-monitoring:1.601.0
podman image rm localhost/au-pod:1.601.0
podman image rm localhost/polaris-keycloak:0.2.0
podman image rm localhost/traefik:2.9.1
podman image rm localhost/vault:1.11.4
podman image rm localhost/consul:1.13.2
podman image rm localhost/telegraf:1.24.0              
podman image rm localhost/enterprise-helm-repo:22.08.1-26
podman image rm localhost/nautilus:1.3.284
podman image rm localhost/features:1.3.81
podman image rm localhost/bucketservice:1.3.62
podman image rm localhost/cloud-extension:1.3.89
podman image rm localhost/trident-svc:1.3.39
podman image rm localhost/storage-provider:1.3.117
podman image rm localhost/activity:1.3.42
podman image rm localhost/credentials:1.3.46
podman image rm localhost/acc-operator:22.05.99
podman image rm localhost/polaris-ui:1.3.264
podman image rm localhost/cert-manager-webhook:v1.9.1
podman image rm localhost/cert-manager-ctl:v1.9.1
podman image rm localhost/cert-manager-cainjector:v1.9.1
podman image rm localhost/cert-manager-controller:v1.9.1
podman image rm localhost/telemetry-service:1.3.51
podman image rm localhost/graphql-server:1.3.111
podman image rm localhost/vcenter-management:1.1.53
podman image rm localhost/vault-controller:1.3.10
podman image rm localhost/tenancy:1.3.36
podman image rm localhost/storage-backend-metrics:1.3.35
podman image rm localhost/public-metrics:1.3.31
podman image rm localhost/polaris-keycloak:0.1.14
podman image rm localhost/packages:0.1.57
podman image rm localhost/openapi:1.3.41
podman image rm localhost/metrics-facade:0.1.25
podman image rm localhost/license:1.3.62
podman image rm localhost/krakend:1.3.53
podman image rm localhost/keycloak-operator:0.1.71
podman image rm localhost/identity:1.3.71
podman image rm localhost/entitlement:1.3.35
podman image rm localhost/composite-volume:1.3.56
podman image rm localhost/composite-compute:1.3.57
podman image rm localhost/cloud-insights-service:1.3.34
podman image rm localhost/certificates:1.1.37
podman image rm localhost/authentication:1.3.34
podman image rm localhost/asup:1.3.53
podman image rm localhost/api-token-authentication:0.3.33
podman image rm localhost/login-ui:1.3.30
podman image rm localhost/avp-operator:0.2.141
podman image rm localhost/vasa-management:0.2.66
podman image rm localhost/remote-plugin-facade:0.2.51
podman image rm localhost/vcenters:0.2.57
podman image rm localhost/aggregate:0.2.57
podman image rm localhost/remote-plugin-ui:0.2.55
podman image rm localhost/vsa-deploy:2022.07.20_acc
podman image rm localhost/gateway:0.2.9
podman image rm localhost/netapp-monitoring:1.381.0
podman image rm localhost/au-pod:1.381.0
podman image rm localhost/cluster-manager:2022.07.01_acc
podman image rm localhost/restic:2.1.202206212337
podman image rm localhost/auth-service:20220621_0730
podman image rm localhost/envoy:v1.22.1
podman image rm localhost/consul:1.12.2
podman image rm localhost/telegraf:1.22.3
podman image rm localhost/vault:1.10.3
podman image rm localhost/traefik:2.6.6
podman image rm localhost/fluent-bit:1.9.3
podman image rm localhost/kube-state-metrics:v2.4.2
podman image rm localhost/mongodb:4.4.11-debian-10-r12
podman image rm localhost/mongodb-exporter:0.11.2-debian-10-r393
podman image rm localhost/enterprise-helm-repo:21.12.60
podman image rm localhost/nautilus:1.1.247
podman image rm localhost/telemetry-service:1.1.33
podman image rm localhost/netapp-monitoring:1.52.0
podman image rm localhost/tenancy:1.1.13
podman image rm localhost/support:1.1.15
podman image rm localhost/identity:1.1.29
podman image rm localhost/features:1.1.35
podman image rm localhost/entitlement:1.1.12
podman image rm localhost/cloud-extension:1.1.51
podman image rm localhost/billing:1.1.15
podman image rm localhost/activity:1.1.21
podman image rm localhost/polaris-ui:1.1.256
podman image rm localhost/storage-provider:1.1.109
podman image rm localhost/acc-operator:21.10.19
podman image rm localhost/graphql-server:1.1.68
podman image rm localhost/public-metrics:1.1.13
podman image rm localhost/krakend:1.1.28
podman image rm localhost/cloud-insights-service:1.1.35
podman image rm localhost/restic:1.0.202111172053
podman image rm localhost/openapi:1.1.16
podman image rm localhost/license:1.1.21
podman image rm localhost/bucketservice:1.1.25
podman image rm localhost/login-ui:1.1.8
podman image rm localhost/credentials:1.1.19
podman image rm localhost/authentication:1.1.12
podman image rm localhost/composite-compute:1.1.32
podman image rm localhost/hybridauth:0.1.4
podman image rm localhost/storage-backend-metrics:1.1.21
podman image rm localhost/metrics-ingestion-service:1.1.8
podman image rm localhost/email:1.1.9
podman image rm localhost/composite-volume:1.1.15
podman image rm localhost/api-token-authentication:0.1.12
podman image rm localhost/trident-svc:1.1.22
podman image rm localhost/astra-py-k8s:v0.0.3
podman image rm localhost/asup:1.1.19
podman image rm localhost/vault-controller:1.1.16
podman image rm localhost/mongodb:4.4.9-debian-10-r21
podman image rm localhost/mongodb-exporter:0.11.2-debian-10-r307
podman image rm localhost/vault:1.8.4
podman image rm localhost/au-pod:0.0.2
podman image rm localhost/cert-manager-cainjector:v1.5.4
podman image rm localhost/cert-manager-controller:v1.5.4
podman image rm localhost/cert-manager-ctl:v1.5.4
podman image rm localhost/cert-manager-webhook:v1.5.4
podman image rm localhost/traefik:2.5.3
podman image rm localhost/telegraf:1.19.3
podman image rm localhost/consul:1.9.9
podman image rm localhost/kube-rbac-proxy:v0.11.0
podman image rm localhost/kubernetes-event-exporter:0.10
podman image rm localhost/kube-state-metrics:v2.1.0
podman image rm localhost/fluent-bit:1.7.8
podman image rm localhost/nats:2.2.6-alpine3.13
podman image rm localhost/auth-service-job:1.17-openjdk
podman image rm localhost/influxdb:v2.0.4
podman image rm localhost/aggregate-job:1.0.0
podman image rm localhost/vcenter-job:1.0.0
podman image rm localhost/kube-rbac-proxy:v0.5.0

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

  source ~/.bashrc
fi
