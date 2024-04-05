#!/bin/bash
# SCRIPT TO RUN ON HELPER1

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
echo "#############################################"
echo "# Unmanage RKE2"
echo "#############################################"
RKE2ID=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/topology/v1/managedClusters" -H "Authorization: Bearer $APITOKEN" | jq -r '.items[] | select(.name=="rke2") | .id')
curl -X DELETE "https://astra.demo.netapp.com/accounts/$ACCOUNTID/topology/v1/managedClusters/$RKE2ID" -H 'accept: */*' -H "Authorization: Bearer $APITOKEN"

CLOUDID=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/topology/v1/clouds" -H "Authorization: Bearer $APITOKEN" | jq -r '.items[].id')
curl -X DELETE "https://astra.demo.netapp.com/accounts/$ACCOUNTID/topology/v1/clouds/$CLOUDID/clusters/$RKE2ID" -H 'accept: */*' -H "Authorization: Bearer $APITOKEN"

sleep 5

echo
echo "#############################################"
echo "# Install Astra Connector Operator on RKE2"
echo "#############################################"
export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
kubectl apply -f https://github.com/NetApp/astra-connector-operator/releases/download/24.02.0-202403151353/astraconnector_operator.yaml

echo
echo "#############################################"
echo "# Create secrets"
echo "#############################################"
kubectl create secret generic astra-token --from-literal=apiToken=$APITOKEN -n astra-connector
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n astra-connector --docker-server=registry.demo.netapp.com

echo
echo "#############################################"
echo "# Deploy the Astra Connector"
echo "#############################################"
cat << EOF | kubectl apply -f -
apiVersion: astra.netapp.io/v1
kind: AstraConnector
metadata:
  name: astra-connector
  namespace: astra-connector
spec:
  astra:
    accountId: $ACCOUNTID
    clusterName: rke2
    skipTLSValidation: true
    tokenRef: astra-token
  natsSyncClient:
    cloudBridgeURL: https://astra.demo.netapp.com
  imageRegistry:
    name: registry.demo.netapp.com/netapp/astra/acc/24.02.0-69
    secret: regcred
EOF

sleep 10

echo
frames="/ | \\ -"
until [[ $(kubectl -n astra-connector get astraconnector astra-connector -o=jsonpath='{.status.natsSyncClient.registered}') == 'true' ]]; do
    for frame in $frames; do
       sleep 1; printf "\rwaiting for the AC Connector installation to be complete $frame"
    done
done

echo
echo "#############################################"
echo "# Astra Connector status"
echo "#############################################"
kubectl get -n astra-connector astraconnector