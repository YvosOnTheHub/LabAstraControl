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
frames="/ | \\ -"

DIR="tmpscript"
[ ! -d "$DIR" ] && mkdir $DIR && cd $DIR

echo
echo "############################################"
echo "# RETRIEVE APP & MIRROR IDs"
echo "############################################"

WORDPRESSID=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps?filter=clusterName%20eq%20%27rke1%27" -H "Authorization: Bearer $APITOKEN" | jq -r '.items[] | select(.name=="wpf") | .id')
MIRRORID=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/appMirrors?include=id" -H "Authorization: Bearer $APITOKEN" | jq -r .items[0][0])

echo
echo "############################################"
echo "# FAILOVER APP ON RKE2"
echo "############################################"

cat > CURL-ACC-wpf-failover-app.json << EOF
{
  "stateDesired": "failedOver",
  "type": "application/astra-appMirror",
  "version": "1.1"
}
EOF

FAILOVERAPP=$(curl -k -s -X PUT "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/appMirrors/$MIRRORID" \
  -H 'accept: application/astra-appMirror+json' -H 'Content-Type: application/astra-appMirror+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wpf-failover-app.json)
FAILOVERID=$(echo $FAILOVERAPP | jq -r .id)

STATE="waitasec"
until [[ $STATE == "failedOver" ]]; do
  FAILOVERDETAILS=$(curl -k -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/appMirrors/$MIRRORID" -H "Authorization: Bearer $APITOKEN")
  STATE=$(echo $FAILOVERDETAILS | jq -r .state)
  for frame in $frames; do
    sleep 1; printf "\rwaiting for the failover to be ready $frame"
  done
done

echo
echo "#################################################"
echo "# END OF THE SCRIPT"
echo "#################################################"