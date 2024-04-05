#########################################################################################
# Addenda 5: How to use the Astra Control Toolkit
#########################################################################################

Astra Control can be used via its GUI, its set of REST API or via SDK (ACToolkit).  

This page will guide you through the installation & configuration of the ACTOOLKIT in the Lab on Demand.  
You can read the documentation of this SDK on the following [link](https://github.com/NetApp/netapp-astra-toolkits).  

The Astra toolkit can be installed in various methods:  
- it can run in its own pre-configured container
- it can be installed through the Python library
- you can install it manually

Let's first explore the Docker version, the local install will covered further down.  
The following command will download the image if not already present, start the container & log you directly in the _apps_ folder.  
Note that the toolkit version compatible with ACC 23.07 is the number 2.6.8 (or 2.6.8-minimal).  
```bash
$ podman run -it docker.io/netapp/astra-toolkits:2.6.8-minimal /bin/bash
Trying to pull docker.io/netapp/astra-toolkits:2.6.8-minimal...
Getting image source signatures
Copying blob 4d9fbb151d79 done  
...
Copying config 9f4f22957b done  
Writing manifest to image destination
Storing signatures
root@2700bc21cbb3:/apps#
```

If you have already upgraded this lab to **ACC 23.10**, I would recommend using the toolkit **v2.6.9** (or 2.6.9-minimal).  

We then need to create the toolkit configuration file, in order for it to communicate with Astra Control.  
You first have to retrieve the ACC Account ID & Token, data that can be retrieved following the [Addenda01](../Addenda01/).  
```bash
mkdir -p ~/.config/astra-toolkits/

export ASTRA_ACCOUNTID=6912cacd-a03a-4f8f-85cb-713ef5253eff
export ASTRA_APIKEY=2sgHm2eiBjn36RM_7pZD1Wiy6T9FV2V1SChmad80Qqo=

cat <<EOT >> ~/.config/astra-toolkits/config.yaml
headers:
  Authorization: Bearer $ASTRA_APIKEY
uid: $ASTRA_ACCOUNTID
astra_project: astra.demo.netapp.com
verifySSL: False
EOT
sed -i '/^$/d' ~/.config/astra-toolkits/config.yaml
```
The last line is just to clean up the config.yaml file and remove empty lines, created by the copy/paste process.  

And that's it! We can now check that the toolkit is working properly:
```bash
$ actoolkit list clusters
+---------------+--------------------------------------+---------------+------------+---------+----------------+-----------------------+
| clusterName   | clusterID                            | clusterType   | location   | state   | managedState   | tridentStateAllowed   |
+===============+======================================+===============+============+=========+================+=======================+
| rke1          | 601ff60e-1fcb-4f69-be89-2a2c4ca5a715 | rke           |            | running | managed        | unmanaged             |
+---------------+--------------------------------------+---------------+------------+---------+----------------+-----------------------+
| rke2          | 4136e7b2-83ae-486a-932c-5258f11dea93 | kubernetes    |            | running | managed        | unmanaged             |
+---------------+--------------------------------------+---------------+------------+---------+----------------+-----------------------+
```

If you are using Astra Control 24.02, the recommmended toolkit version is 3.0.0.  
For this one, let's see how to install it locally (on the _helper1_ host):
```bash
$ python3 -m pip install actoolkit
$ pip install --upgrade actoolkit=3.0.0

$ mkdir -p ~/.config/astra-toolkits/

$ export ASTRA_ACCOUNTID=feb2b2c9-f3a7-4dec-a351-8ed73c0a44e0
$ export ASTRA_APIKEY=BXiFzlBu6uqQV3PMauuYrd0tenljfzKuf_kuREgoMiI=

$ cat <<EOT >> ~/.config/astra-toolkits/config.yaml
headers:
  Authorization: Bearer $ASTRA_APIKEY
uid: $ASTRA_ACCOUNTID
astra_project: astra.demo.netapp.com
verifySSL: False
EOT
sed -i '/^$/d' ~/.config/astra-toolkits/config.yaml

$ actoolkit list clusters
+---------------+--------------------------------------+---------------+------------+---------+----------------+-----------------------+
| clusterName   | clusterID                            | clusterType   | location   | state   | managedState   | tridentStateAllowed   |
+===============+======================================+===============+============+=========+================+=======================+
| rke2          | 4136e7b2-83ae-486a-932c-5258f11dea93 | kubernetes    |            | running | managed        | unmanaged             |
+---------------+--------------------------------------+---------------+------------+---------+----------------+-----------------------+
| rke1          | 601ff60e-1fcb-4f69-be89-2a2c4ca5a715 | rke           |            | running | managed        | unmanaged             |
+---------------+--------------------------------------+---------------+------------+---------+----------------+-----------------------+
```
Also quite easy!  
This version allows you to interact with the Astra Connector, & can be useful to build the YAML manifests you need.  

Here is an example I used to create a IPR CR (InPlaceRestore).  
The key options are _--dry-run_ and _--v3_:  
```bash
$  actoolkit --dry-run=client --v3 ipr --backup hourly-20595-20240404175000 wpargo --filterSelection include --filterSet version=v1,kind=PersistentVolumeClaim,name=mysql-pvc
apiVersion: astra.netapp.io/v1
kind: BackupInplaceRestore
metadata:
  name: backupipr-e96924d1-2ed7-4728-bb5d-ab60c3b97c0d
  namespace: astra-connector
spec:
  appArchivePath: wpargo_5f874563-85e6-44d1-9317-1690a9110318/backups/hourly-20595-20240404175000_93c5ed60-4bbc-46b1-8b77-00358a876c8b
  appVaultRef: rke2-appvault
  resourceFilter:
    resourceMatchers:
    - kind: PersistentVolumeClaim
      names:
      - mysql-pvc
      version: v1
    resourceSelectionCriteria: include
```

Tadaaa !