#!/bin/bash
# SCRIPT TO RUN ON THE JUMPHOST

# ACCOUNT ID    feb2b2c9-f3a7-4dec-a351-8ed73c0a44e0
# RKE1 ID       601ff60e-1fcb-4f69-be89-2a2c4ca5a715
# RKE2 ID       4136e7b2-83ae-486a-932c-5258f11dea93

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

mkdir tmpscript
cd tmpscript

echo
echo "############################################"
echo "# ENABLE HOOKS IF NEEDED"
echo "############################################"

SETTINGS=$(curl -k -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/settings" -H "Authorization: Bearer $APITOKEN")
HOOKFEATURE=$(echo $SETTINGS | jq -r '.items[] | select(.name == "astra.account.executionHooks.enabled")')
HOOKFEATURESTATUS=$(echo $HOOKFEATURE | jq -r .currentConfig.isEnabled)
HOOKFEATUREID=$(echo $HOOKFEATURE | jq -r .id)

if [ $HOOKFEATURESTATUS eq 'false' ]; then
  cat > CURL-ACC-Hook-Enable.json << EOF
{
  "desiredConfig": {"isEnabled": "true"},
  "type": "application/astra-setting",
  "version": "1.1"
}
EOF

  curl -k -X PUT "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/settings/$HOOKFEATUREID" \
  -H 'accept: application/astra-setting+json' -H 'Content-Type: application/astra-setting+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Hook-Enable.json
fi

echo
echo "############################################"
echo "# ADD POST-RESTORE REPLICAS HOOK TO ACC"
echo "############################################"

HOOKREPLICAS=$(base64 -w 0 ~/LabAstraControl/LoD_ACC_v1.4/Scenarios-ACC/Scenario05/1-Post-Restore/hook-restore-replicas.sh)

cat > CURL-ACC-Hook-REPLICAS.json << EOF
{
  "description": "Post-restore hook to modify the number of replicas",
  "name": "PR-Replicas",
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

HOOKTAGS=$(base64 -w 0 ~/LabAstraControl/LoD_ACC_v1.4/Scenarios-ACC/Scenario05/1-Post-Restore/hook-restore-tag-rewrite.sh)

cat > CURL-ACC-Hook-TAGS.json << EOF
{
  "description": "Post-restore hook to modify the target images tag",
  "name": "PR-Tags-Update",
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
    echo
    echo "############################################"
    echo "# CLONE VERDA REPO"
    echo "############################################"
    git clone https://github.com/NetApp/Verda.git ~/Verda

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

    curl -o /dev/null -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/hookSources" \
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

cat > CURL-ACC-wphook-manage-app.json << EOF
{
  "clusterID": "601ff60e-1fcb-4f69-be89-2a2c4ca5a715",
  "name": "wphook",
  "namespaceScopedResources": [{"namespace": "wphook"}],
  "type": "application/astra-app",
  "version": "2.2"
}
EOF

MANAGEAPP=$(curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8S/v2/apps" \
  -H 'accept: application/astra-app+json' -H 'Content-Type: application/astra-app+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wphook-manage-app.json)

WORDPRESSID=$(echo $MANAGEAPP | jq -r .id)

echo
echo "############################################"
echo "# ADD A PRESNAPSHOT HOOK FOR MARIADB"
echo "############################################"
cat > CURL-ACC-wphook-hook1.json << EOF
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

curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8S/v1/apps/$WORDPRESSID/executionHooks" \
  -H 'accept: application/astra-executionHook+json' -H 'Content-Type: application/astra-executionHook+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wphook-hook1.json

echo
echo "############################################"
echo "# ADD A POSTSNAPSHOT HOOK FOR MARIADB"
echo "############################################"
cat > CURL-ACC-wphook-hook2.json << EOF
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

curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8S/v1/apps/$WORDPRESSID/executionHooks" \
  -H 'accept: application/astra-executionHook+json' -H 'Content-Type: application/astra-executionHook+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wphook-hook2.json

echo
echo "################################################"
echo "# ADD THE FIRST POSTRESTORE HOOK FOR WORDPRESS"
echo "################################################"
cat > CURL-ACC-wphook-hook3.json << EOF
{
  "type": "application/astra-executionHook",
  "version": "1.3",
  "name": "WordpressScale",
  "hookType": "custom",
  "action": "restore",
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

curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8S/v1/apps/$WORDPRESSID/executionHooks" \
  -H 'accept: application/astra-executionHook+json' -H 'Content-Type: application/astra-executionHook+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wphook-hook3.json

echo
echo "#################################################"
echo "# ADD THE SECOND POSTRESTORE HOOK FOR WORDPRESS"
echo "#################################################"
cat > CURL-ACC-wphook-hook4.json << EOF
{
  "type": "application/astra-executionHook",
  "version": "1.3",
  "name": "WordpressTags",
  "hookType": "custom",
  "action": "restore",
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

curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/k8S/v1/apps/$WORDPRESSID/executionHooks" \
  -H 'accept: application/astra-executionHook+json' -H 'Content-Type: application/astra-executionHook+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-wphook-hook4.json