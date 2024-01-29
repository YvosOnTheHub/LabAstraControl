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
[ -d "$DIR" ] && rm -rf $DIR
mkdir $DIR && cd $DIR

echo
echo "############################################"
echo "# ADD POST-FAILOVER REPLICAS HOOK TO ACC"
echo "############################################"

HOOKREPLICAS=$(base64 -w 0 ~/LabAstraControl/LoD_ACC_v1.4/Scenarios-ACC/Scenario05/2-Post-Failover/hook-failover-replicas.sh)

cat > CURL-ACC-Hook-REPLICAS.json << EOF
{
  "description": "Post-failover hook to modify the number of replicas",
  "name": "PF-Replicas",
  "source": "$HOOKREPLICAS",
  "sourceType": "script",
  "type": "application/astra-hookSource",
  "version": "1.0"
}
EOF

curl -s -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/hookSources" \
  -H 'accept: application/astra-hookSource+json' -H 'Content-Type: application/astra-hookSource+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Hook-REPLICAS.json

echo
echo "############################################"
echo "# ADD POST-RESTORE TAG UPDATE HOOK TO ACC"
echo "############################################"

HOOKTAGS=$(base64 -w 0 ~/LabAstraControl/LoD_ACC_v1.4/Scenarios-ACC/Scenario05/2-Post-Failover/hook-failover-tag-rewrite.sh)

cat > CURL-ACC-Hook-TAGS.json << EOF
{
  "description": "Post-failover hook to modify the target images tag",
  "name": "PF-Tags-Update",
  "source": "$HOOKTAGS",
  "sourceType": "script",
  "type": "application/astra-hookSource",
  "version": "1.0"
}
EOF

curl -s -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/hookSources" \
  -H 'accept: application/astra-hookSource+json' -H 'Content-Type: application/astra-hookSource+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Hook-TAGS.json

HOOKLIST=$(curl -s -k -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/hookSources" -H "Authorization: Bearer $APITOKEN")
ISMARIADB=$(echo $HOOKLIST | jq -r '.items[] | select(.name | contains("maria"))')

if [ -z "$ISMARIADB" ]; then
    DIR="/root/Verda"
    if [ ! -d "$DIR" ]; then
      echo
      echo "############################################"
      echo "# CLONE VERDA REPO"
      echo "############################################"
      git clone https://github.com/NetApp/Verda.git ~/Verda
    fi

    echo
    echo "############################################"
    echo "# ADD MARIADB/MYSQL HOOK TO ACC"
    echo "############################################"

    HOOKMARIADB=$(base64 -w 0 ~/Verda/Mariadb-MySQL/mariadb_mysql.sh)

cat > CURL-ACC-Hook-MARIADB.json << EOF
{
  "description": "Pre and post hook script for MariaDB & MySQL",
  "name": "mariadb-MySQL",
  "source": "$HOOKMARIADB",
  "sourceType": "script",
  "type": "application/astra-hookSource",
  "version": "1.0"
}
EOF

    curl -s -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/hookSources" \
        -H 'accept: application/astra-hookSource+json' -H 'Content-Type: application/astra-hookSource+json' \
        -H "Authorization: Bearer $APITOKEN" \
        -d @CURL-ACC-Hook-MARIADB.json

    HOOKLIST=$(curl -s -k -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/hookSources" -H "Authorization: Bearer $APITOKEN")
fi

echo
echo "############################################"
echo "# GET HOOKS ID"
echo "############################################"

HOOKREPLICASID=$(echo $HOOKLIST | jq -r '.items[] | select(.name | contains("Replicas")) | .id')
HOOKTAGSID=$(echo $HOOKLIST | jq -r '.items[] | select(.name | contains("Tags")) | .id')
HOOKMARIADBID=$(echo $HOOKLIST | jq -r '.items[] | select(.name | contains("maria")) | .id')

echo
echo "############################################"
echo "# MANAGE THE WORDPRESS APP"
echo "############################################"

cat > CURL-ACC-wpf-manage-app.json << EOF
{
  "clusterID": "601ff60e-1fcb-4f69-be89-2a2c4ca5a715",
  "name": "wpf",
  "namespaceScopedResources": [{"namespace": "wpf"}],
  "type": "application/astra-app",
  "version": "2.2"
}
EOF

MANAGEAPP=$(curl -k -s -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps" \
  -H 'accept: application/astra-app+json' -H 'Content-Type: application/astra-app+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wpf-manage-app.json)
WORDPRESSID=$(echo $MANAGEAPP | jq -r .id)

STATE="waitasec"
until [[ $STATE == "ready" ]]; do
  WORDPRESSDETAILS=$(curl -k -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v2/apps/$WORDPRESSID" -H "Authorization: Bearer $APITOKEN")
  STATE=$(echo $WORDPRESSDETAILS | jq -r .state)
  for frame in $frames; do
    sleep 1; printf "\rwaiting for the Wordpress app to be ready $frame"
  done
done

echo
echo "############################################"
echo "# ADD A PRESNAPSHOT HOOK FOR MARIADB"
echo "############################################"
cat > CURL-ACC-wpf-hook1.json << EOF
{
  "type": "application/astra-executionHook",
  "version": "1.3",
  "name": "MariaPRE",
  "hookType": "custom",
  "action": "snapshot",
  "stage": "pre",
  "hookSourceID": "$HOOKMARIADBID",
  "arguments": [
    "pre"
  ],
  "matchingCriteria": [{
    "type": "containerImage",
    "value": "maria"
  }],
  "appID": "$WORDPRESSID",
  "enabled": "true",
  "description": "MariaDB pre snapshot hook"
}
EOF

curl -s -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/executionHooks" \
  -H 'accept: application/astra-executionHook+json' -H 'Content-Type: application/astra-executionHook+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wpf-hook1.json

echo
echo "############################################"
echo "# ADD A POSTSNAPSHOT HOOK FOR MARIADB"
echo "############################################"
cat > CURL-ACC-wpf-hook2.json << EOF
{
  "type": "application/astra-executionHook",
  "version": "1.3",
  "name": "MariaPOST",
  "hookType": "custom",
  "action": "snapshot",
  "stage": "pre",
  "hookSourceID": "$HOOKMARIADBID",
  "arguments": [
    "post"
  ],
  "matchingCriteria": [{
    "type": "containerImage",
    "value": "maria"
  }],
  "appID": "$WORDPRESSID",
  "enabled": "true",
  "description": "MariaDB post snapshot hook"
}
EOF

curl -s -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/executionHooks" \
  -H 'accept: application/astra-executionHook+json' -H 'Content-Type: application/astra-executionHook+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wpf-hook2.json

echo
echo "################################################"
echo "# ADD THE FIRST POSTFAILOVER HOOK FOR WORDPRESS"
echo "################################################"
cat > CURL-ACC-wpf-hook3.json << EOF
{
  "type": "application/astra-executionHook",
  "version": "1.3",
  "name": "WordpressScale",
  "hookType": "custom",
  "action": "failover",
  "stage": "post",
  "hookSourceID": "$HOOKREPLICASID",
  "arguments": [
    "wordpress",
    "1"
  ],
  "matchingCriteria": [{
    "type": "containerImage",
    "value": "alpine"
  }],
  "appID": "$WORDPRESSID",
  "enabled": "true",
  "description": "MariaDB post restore hook to scale down the app"
}
EOF

curl -s -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/executionHooks" \
  -H 'accept: application/astra-executionHook+json' -H 'Content-Type: application/astra-executionHook+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wpf-hook3.json

echo
echo "#################################################"
echo "# ADD THE SECOND POSTFAILOVER HOOK FOR WORDPRESS"
echo "#################################################"
cat > CURL-ACC-wpf-hook4.json << EOF
{
  "type": "application/astra-executionHook",
  "version": "1.3",
  "name": "WordpressTags",
  "hookType": "custom",
  "action": "failover",
  "stage": "post",
  "hookSourceID": "$HOOKTAGSID",
  "arguments": [
    "site1",
    "site2"
  ],
  "matchingCriteria": [{
    "type": "containerImage",
    "value": "alpine"
  }],
  "appID": "$WORDPRESSID",
  "enabled": "true",
  "description": "MariaDB post restore hook to update the images'tags"
}
EOF

curl -s -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/executionHooks" \
  -H 'accept: application/astra-executionHook+json' -H 'Content-Type: application/astra-executionHook+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wpf-hook4.json

echo
echo "#################################################"
echo "# CREATE THE MIRROR RELATIONSHIP"
echo "#################################################"
cat > CURL-ACC-wpf-replication.json << EOF
{
  "destinationClusterID": "4136e7b2-83ae-486a-932c-5258f11dea93",
  "sourceAppID": "$WORDPRESSID",
  "stateDesired": "established",
  "storageClasses":[{ "clusterID": "4136e7b2-83ae-486a-932c-5258f11dea93", "role": "destination", "storageClassName": "sc-nas-svm2" }],
  "type": "application/astra-appMirror",
  "version": "1.1"
}
EOF

MIRRORPOST=$(curl -k -s -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/appMirrors" \
  -H 'accept: application/astra-appMirror+json' -H 'Content-Type: application/astra-appMirror+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wpf-replication.json)
MIRRORID=$(echo $MIRRORPOST | jq -r .id)

STATE="waitasec"
until [[ $STATE == "established" ]]; do
  MIRRORDETAILS=$(curl -k -s -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8s/v1/apps/$WORDPRESSID/appMirrors/$MIRRORID" -H "Authorization: Bearer $APITOKEN")
  STATE=$(echo $MIRRORDETAILS | jq -r .state)
  for frame in $frames; do
    sleep 1; printf "\rwaiting for the mirror relationship to be ready $frame"
  done
done

echo
echo "#################################################"
echo "# END OF THE SCRIPT"
echo "#################################################"