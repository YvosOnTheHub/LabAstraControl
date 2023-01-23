# SCRIPT TO RUN ON THE JUMPHOST

: <<'END'
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
END

ACCOUNTID="6912cacd-a03a-4f8f-85cb-713ef5253eff"
APITOKEN="60BJzXpoYzpjRFclFyW94TzyTxi_lzVxZfvfNkMn1CU="

BUCKETID="72db9754-892e-4982-be42-4e6b4b32ec0d"
RKE1ID="1ceedd15-f771-4f13-84ac-bf181148b202"
RKE2ID="1a18ac44-0057-47e3-a2ee-09f3cd61ab05"

sudo apt install -y jq
sudo rm -f 'google-chrome.list'$'\r'

echo
echo "############################################"
echo "# UNMANAGE NETAPP-ACC"
echo "############################################"

curl -k -X DELETE "https://astra.demo.netapp.com/accounts/$ACCOUNTID//k8s/v2/apps/a3c793aa-ee99-4098-b4f8-8fe86f9b2c74" \
  -H 'accept: */*' -H "Authorization: Bearer $APITOKEN"

echo
echo "############################################"
echo "# ADD MONGODB HOOK TO ACC"
echo "############################################"

HOOKMONGODB=$(base64 -w 0 ~/Verda/MongoDB/mongodb-hooks.sh)

cat > CURL-ACC-Hook-MONGODB.json << EOF
{
  "description": "Pre and post hook script for MongoDB",
  "name": "MongoDB",
  "source": "$HOOKMONGODB",
  "sourceType": "script",
  "type": "application/astra-hookSource",
  "version": "1.0"
}
EOF

CREATEMONGODBHOOK=$(curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/hookSources" \
  -H 'accept: application/astra-hookSource+json' -H 'Content-Type: application/astra-hookSource+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Hook-MONGODB.json)

MONGODBHOOKID=$(echo $CREATEMONGODBHOOK | jq -r .id)

: <<'END'
echo
echo "############################################"
echo "# RETRIEVE PACMAN NAMESPACE'S ID"
echo "############################################"

PACMANNAMESPACE=$(curl -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/topology/v1/managedClusters/$RKE2ID/namespaces?include=id%2Cname%2Cname&filter=name%20eq%20%27pacman%27" \
  -H 'accept: application/json' -H "Authorization: Bearer $APITOKEN")

PACMANNAMESPACEID=$(echo $PACMANNAMESPACE | jq -r .items[0][0])
END

echo
echo "############################################"
echo "# MANAGE PACMAN"
echo "############################################"

cat > CURL-ACC-Pacman-Manage.json << EOF
{
  "clusterID": "$RKE2ID",
  "name": "pacman",
  "namespaceScopedResources": [{ "namespace": "pacman" }],
  "type": "application/astra-app",
  "version": "2.1"
}
EOF

PACMANAPP=$(curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps" \
  -H 'accept: application/astra-app+json' -H 'Content-Type: application/astra-app+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Pacman-Manage.json)

PACMANAPPID=$(echo $PACMANAPP | jq -r .id)


echo
echo "############################################"
echo "# CREATE AN ON-DEMAND SNAPSHOT FOR PACMAN"
echo "############################################"

PACMANSNAP=$(curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$PACMANAPPID/appSnaps" \
  -H 'accept: application/astra-appSnap+json' -H 'Content-Type: application/astra-appSnap+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d '{
  "name": "pacman-ondemand-snap1",
  "type": "application/astra-appSnap",
  "version": "1.1"
}')

PACMANSNAPID=$(echo $PACMANSNAP | jq -r .id)

PACMANSNAPSTATE="UNKNOWN"
until [ $PACMANSNAPSTATE = 'completed' ]; do
  PACMANSNAPGET=$(curl -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$PACMANAPPID/appSnaps/$PACMANSNAPID" \
  -H 'accept: application/astra-appSnap+json' -H "Authorization: Bearer $APITOKEN")

  PACMANSNAPSTATE=$(echo $PACMANSNAPGET | jq -r .state)
  sleep 5
done;


echo
echo "############################################"
echo "# CREATE AN ON-DEMAND BACKUP FOR PACMAN"
echo "############################################"

cat > CURL-ACC-Pacman-onDemand-Backup.json << EOF
{
  "name": "pacman-ondemand-bakp1",
  "type": "application/astra-appSnap",
  "snapshotID": "$PACMANSNAPID",
  "version": "1.1"
}
EOF

PACMANBKP=$(curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$PACMANAPPID/appBackups" \
  -H 'accept: application/astra-appBackup+json' -H 'Content-Type: application/astra-appBackup+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Pacman-onDemand-Backup.json)

PACMANBKPID=$(echo $PACMANBKP | jq -r .id)

PACMANBKPSTATE="UNKNOWN"
until [ $PACMANBKPSTATE = 'completed' ]; do
  PACMANBKPGET=$(curl -k -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$PACMANAPPID/appBackups/$PACMANBKPID" \
  -H 'accept: application/astra-appBackup+json' -H "Authorization: Bearer $APITOKEN")

  PACMANBKPSTATE=$(echo $PACMANBKPGET | jq -r .state)
  sleep 5
done;


echo
echo "############################################"
echo "# CREATE A PROTECTION POLICY FOR PACMAN"
echo "############################################"

cat > CURL-ACC-Pacman-Protection-Policy.json << EOF
{
  "backupRetention": "8",
  "enabled": "true",
  "granularity": "hourly",
  "minute": "0",
  "name": "Pacman-protection-schedule",
  "snapshotRetention": "4",
  "type": "application/astra-schedule",
  "version": "1.3"
}
EOF

curl -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$PACMANAPPID/schedules" \
  -H 'accept: application/astra-schedule+json' -H 'Content-Type: application/astra-schedule+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Pacman-Protection-Policy.json

echo
echo "#######################################################"
echo "# CREATE A REPLICATION POLICY FOR PACMAN (RKE2=>RKE1)"
echo "#######################################################"

cat > CURL-ACC-Pacman-Replication-Policy.json << EOF
{
  "destinationClusterID": "$RKE1ID",
  "namespaceMapping": [
    { "clusterID": "$RKE2ID", "namespaces": ["pacman"] },
    { "clusterID": "$RKE1ID", "namespaces": ["pacman-drp"] }
  ],
  "sourceAppID": "$PACMANAPPID",
  "stateDesired": "established",
  "storageClasses": [
    "clusterID": "$RKE1ID",
    "storageClassName": "sc-nas-svm1"
    ],
  "type": "application/astra-appMirror",
  "version": "1.0"
}
EOF

curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$PACMANAPPID/appMirrors" \
  -H 'accept: application/astra-appMirror+json' -H 'Content-Type: application/astra-appMirror+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Pacman-Replication-Policy.json