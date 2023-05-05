#########################################################################################
# Addenda 3: How to use the Astra Control Toolkit
#########################################################################################

Astra Control can be used via its GUI, its set of REST API or via SDK (ACToolkit).  

This page will guide you through the installation & configuration of the ACTOOLKIT in the Lab on Demand.  
You can read the documentation of this SDK on the following [link](https://github.com/NetApp/netapp-astra-toolkits).  

The Astra toolkit can be installed in various methods:  
- it can run in its own pre-configured container
- it can be installed through the Python library
- you can install it manually

The easiest way, in the Lab on Demand, is to run it with Docker, as you dont need to install the prerequisites.  
The following command will download the image if not already present, start the container & log you directly in the _apps_ folder.  
```bash
$ podman run -it docker.io/netapp/astra-toolkits:latest /bin/bash
Trying to pull docker.io/netapp/astra-toolkits:latest...
Getting image source signatures
Copying blob 95c4824f32c4 done  
Copying blob dbf6a9befcde done  
Copying blob 57746fbee1a8 done  
Copying blob 61afd8637bc9 done  
Copying blob 693618a01b07 done  
Copying blob b1a6deebff76 done  
Copying blob 48ba9224502a done  
Copying blob 89425d710074 done  
Copying blob ab956d0a7e9d done  
Copying config 98e9a84d31 done  
Writing manifest to image destination
Storing signatures
root@2700bc21cbb3:/apps#
```

We then need to create the toolkit configuration file, in order for it to communicate with Astra Control.  
You first have to retrieve the ACC Account ID & Token, data that can be retrieved following the [Addenda01](../Addenda01/).  
```bash
mkdir -p ~/.config/astra-toolkits/

export ASTRA_ACCOUNTID=6912cacd-a03a-4f8f-85cb-713ef5253eff
export ASTRA_APIKEY=DMqUWjVxpFyrumuMWWi6RLoXo6ljS5VUorAnXNJizoE=

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
| rke1          | 1ceedd15-f771-4f13-84ac-bf181148b202 | kubernetes    |            | running | managed        |                       |
+---------------+--------------------------------------+---------------+------------+---------+----------------+-----------------------+
| rke2          | 1a18ac44-0057-47e3-a2ee-09f3cd61ab05 | kubernetes    |            | running | managed        |                       |
+---------------+--------------------------------------+---------------+------------+---------+----------------+-----------------------+
```

Tadaaa !