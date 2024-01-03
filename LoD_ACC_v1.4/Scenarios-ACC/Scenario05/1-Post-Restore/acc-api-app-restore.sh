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
echo "# RETRIEVE APP & BACKUP IDs"
echo "############################################"

WORDPRESSID=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps?include=id&filter=name%20eq%20%27wphook%27" -H "Authorization: Bearer $APITOKEN" | jq -r .items[0][0])
BACKUPID=$(curl -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/appBackups?include=id%2Cname" -H "Authorization: Bearer $APITOKEN" | jq -r .items[0][0])

echo
echo "############################################"
echo "# RESTORE APP ON RKE2"
echo "############################################"

cat > CURL-ACC-wphook-restore-app.json << EOF
{
  "backupID": "$BACKUPID",
  "clusterID": "4136e7b2-83ae-486a-932c-5258f11dea93",
  "sourceClusterID": "601ff60e-1fcb-4f69-be89-2a2c4ca5a715",
  "name": "wphookrestore",
  "namespaceMapping": [{"destination": "wphookrestore", "source": "wphook" }],
  "storageClassMapping": [{ "destination": "sc-nas-svm2", "source": "*" }],
  "type": "application/astra-app",
  "version": "2.2"
}
EOF

RESTOREAPP=$(curl -k -s -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps" \
  -H 'accept: application/astra-app+json' -H 'Content-Type: application/astra-app+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wphook-restore-app.json)
RESTOREID=$(echo $RESTOREAPP | jq -r .id)

STATE="waitasec"
until [[ $STATE == "ready" ]]; do
  RESTOREDETAILS=$(curl -k -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps/$RESTOREID" -H "Authorization: Bearer $APITOKEN")
  STATE=$(echo $RESTOREDETAILS | jq -r .state)
  for frame in $frames; do
    sleep 1; printf "\rwaiting for the restore to be ready $frame"
  done
done

echo
echo "#################################################"
echo "# END OF THE SCRIPT"
echo "#################################################"