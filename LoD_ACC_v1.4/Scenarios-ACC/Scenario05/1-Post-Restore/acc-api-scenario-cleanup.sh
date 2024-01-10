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

WORDPRESSID=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps?include=id&filter=name%20eq%20%27wpbrhook%27" -H "Authorization: Bearer $APITOKEN" | jq -r .items[0][0])
WORDPRESSRESTOREID=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps?include=id&filter=name%20eq%20%27wpbrhookrestore%27" -H "Authorization: Bearer $APITOKEN" | jq -r .items[0][0])

echo
echo "############################################"
echo "# UNMANAGE THE 2 APPS"
echo "############################################"

curl -X DELETE "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps/$WORDPRESSID" -H 'accept: */*' -H "Authorization: Bearer $APITOKEN"
curl -X DELETE "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps/$WORDPRESSRESTOREID" -H 'accept: */*' -H "Authorization: Bearer $APITOKEN"

echo
echo "############################################"
echo "# DELETE WPBRHOOKRESTORE ON RKE2"
echo "############################################"
export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
helm delete wpbrhook -n wpbrhookrestore
kubectl patch -n wpbrhookrestore rolebinding kubectl-ns-admin-sa -p '{"metadata":{"finalizers":[]}}' --type='merge'
kubectl delete ns wpbrhookrestore

echo
echo "############################################"
echo "# DELETE WPBRHOOK ON RKE1"
echo "############################################"
export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
helm delete wpbrhook -n wpbrhook
kubectl patch -n wpbrhook rolebinding kubectl-ns-admin-sa -p '{"metadata":{"finalizers":[]}}' --type='merge'
kubectl delete ns wpbrhook
