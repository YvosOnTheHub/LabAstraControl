#!/bin/bash
# SCRIPT TO RUN ON THE HELPER1 HOST

# ACCOUNT ID    feb2b2c9-f3a7-4dec-a351-8ed73c0a44e0
# RKE1 ID       601ff60e-1fcb-4f69-be89-2a2c4ca5a715
# RKE2 ID       4136e7b2-83ae-486a-932c-5258f11dea93
# Bucket ID     0509922e-9919-49b6-8cde-5a930dcabd72

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: ACC Account ID"
    echo " - Parameter2: ACC API Token"
    exit 0
fi

ACCOUNTID=$1
APITOKEN=$2

echo
echo "############################################"
echo "# RETRIEVE APP IDs"
echo "############################################"

WORDPRESSIDS=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps?filter=name%20eq%20%27wpbr%27" -H "Authorization: Bearer $APITOKEN")
APP1=$(echo $WORDPRESSIDS | jq -r '.items[] | select(.clusterName=="rke1") | .id')
APP2=$(echo $WORDPRESSIDS | jq -r '.items[] | select(.clusterName=="rke2") | .id')


echo
echo "############################################"
echo "# UNMANAGE THE 2 APPS"
echo "############################################"

curl -X DELETE "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps/$APP1" -H 'accept: */*' -H "Authorization: Bearer $APITOKEN"
curl -X DELETE "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps/$APP2" -H 'accept: */*' -H "Authorization: Bearer $APITOKEN"

echo
echo "############################################"
echo "# DELETE WPBR ON RKE2"
echo "############################################"
export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
helm delete wpbr -n wpbr
kubectl patch -n wpbr rolebinding kubectl-ns-admin-sa -p '{"metadata":{"finalizers":[]}}' --type='merge'
kubectl delete ns wpbr

echo
echo "############################################"
echo "# DELETE WPBR ON RKE1"
echo "############################################"
export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
helm delete wpbr -n wpbr
kubectl patch -n wpbr rolebinding kubectl-ns-admin-sa -p '{"metadata":{"finalizers":[]}}' --type='merge'
kubectl delete ns wpbr
