#########################################################################################
# SCENARIO 1: Configure the lab for iSCSI  
#########################################################################################

**GOAL:**  
This lab is configured to provide persitent volumes based on NFS (Trident ONTAP-NAS driver).  
You may also want to take a look at iSCSI to host your data.  
Astra Control Center supports **ONTAP-SAN** & **ONTAP-SAN-ECONOMY** Trident drivers, granted DR is not possible with the ECONOMY one.  

The scenario will guide you through the following steps:
- Configure & enable the iSCSI protocol on both Kubernetes nodes  
- Configure iSCSI & create LIFs on both ONTAP clusters in the existing SVMs  
- Create new Trident backends with ONTAP-SAN & ONTAP-SAN-ECONOMY
- Create new storage classes

This folder also contains an **all_in_one.sh** script that can perform all these tasks for you (to run in the host _HELPER1_).  

## A. Configure iSCSI on Kubernetes nodes  

You need to edit the following files in order to follow Trident's best practices:  

- _/etc/iscsi/iscsi.conf_ (Open-iSCSI configuration file)  
Deactivate automatic session scans & set this to _manual_

```bash
sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf
```

- _/etc/multipath.conf_ (Multipathing configuration file)  
Enforce  the use of multipathing configuration

```bash
sed -i '2 a \    find_multipaths no' /etc/multipath.conf
```

- _/etc/iscsi/initiatorname.iscsi_ (Host IQN)
Change the last character of the IQN **on each node** to reflect uniqueness.  
in the following command _$i_ must be unique to each host.

```bash
sed -i /iqn/s/.$/$i/ /etc/iscsi/initiatorname.iscsi
```

- finally, restart both services  

```bash
systemctl restart iscsid
systemctl restart multipathd
```

There you go, after having done that on all 10 nodes of this lab, you can move on to the next paragraph.  
  

## B. Configure both ONTAP SVM to allow iSCSI services

ONTAP an be configured in many ways. The all_in_one file uses REST API.  
However, I will use CLI here to make it easier to read.  

Configuring iSCSI in an existing SVM consists in creating one LIF per node & enabling the iSCSI service. Pretty straightforward...  
Commands will run after connecting to the cluster via SSH (_ssh cluster1_ & _ssh cluster3_)

- Let's create 2 iSCSI LIF on _SVM1_ hosted in _cluster1_ as well as enable the iSCSI service

```bash
network interface create -vserver svm1 -lif iSCSIlif1 -service-policy default-data-iscsi -address 192.168.0.245 -netmask 255.255.255.0 -home-node cluster1-01 -home-port e0d 
network interface create -vserver svm1 -lif iSCSIlif2 -service-policy default-data-iscsi -address 192.168.0.246 -netmask 255.255.255.0 -home-node cluster1-02 -home-port e0d 
iscsi create -target-alias svm1 -status-admin up -vserver svm1
```

- Now, let's care about _SVM2_ on _cluster3_

```bash
network interface create -vserver svm2 -lif iSCSIlif1 -service-policy default-data-iscsi -address 192.168.0.247 -netmask 255.255.255.0 -home-node cluster3-01 -home-port e0d 
iscsi create -target-alias svm2 -status-admin up -vserver svm2
```

## C. Create new Trident backends with ONTAP-SAN & ONTAP-SAN-ECONOMY

This paragraph must be run from the HERLPER1 host of the lab, as it contains the _tridentctl_ binary.  
To simplify the following tests, make sure to copy this binary to the /usr/bin folder.  

As there are 2 Rancher clusters, we will install 2 new backends per cluster. To switch between clusters (ie point to the right kubeconfig file), you can use the aliases _rke1_ and _rke2_. At any point in time, you can also verify which kubeconfig file you are defaulting to, by typing the alias _active_.  

```bash
$ rke1
$ tridentctl -n trident create backend -f rke1_trident_svm1_san_backend.json 
+----------+----------------+--------------------------------------+--------+---------+
| NAME     | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+----------+----------------+--------------------------------------+--------+---------+
| svm1-san | ontap-san      | cdc59424-33cd-40af-9c9c-c42dc076f980 | online |       0 |
+----------+----------------+--------------------------------------+--------+---------+

$ tridentctl -n trident create backend -f rke1_trident_svm1_san_eco_backend.json 
+--------------+-------------------+--------------------------------------+--------+---------+
|   NAME       |  STORAGE DRIVER   |                 UUID                 | STATE  | VOLUMES |
+--------------+-------------------+--------------------------------------+--------+---------+
| svm1-san-eco | ontap-san-economy | d24a3b00-4d1f-4658-862c-c4eefec691af | online |       0 |
+--------------+-------------------+--------------------------------------+--------+---------+

$ tridentctl -n trident get backend
+--------------+-------------------+--------------------------------------+--------+---------+
|   NAME       |  STORAGE DRIVER   |                 UUID                 | STATE  | VOLUMES |
+--------------+-------------------+--------------------------------------+--------+---------+
| svm1-san     | ontap-san         | cdc59424-33cd-40af-9c9c-c42dc076f980 | online |       0 |
| svm1-san-eco | ontap-san-economy | d24a3b00-4d1f-4658-862c-c4eefec691af | online |       0 |
| svm1-nas     | ontap-nas         | 9604cbd3-3dee-4cc7-aa02-9ddf07f008d8 | online |      16 |
+--------------+-------------------+--------------------------------------+--------+---------+
```

Let's do the same this for the cluster RKE2:
```bash
$ rke2
$ tridentctl -n trident create backend -f rke2_trident_svm2_san_backend.json 
+----------+----------------+--------------------------------------+--------+---------+
| NAME     | STORAGE DRIVER |                 UUID                 | STATE  | VOLUMES |
+----------+----------------+--------------------------------------+--------+---------+
| svm2-san | ontap-san      | cdc59424-33cd-40af-9c9c-c42dc076a123 | online |       0 |
+----------+----------------+--------------------------------------+--------+---------+

$ tridentctl -n trident create backend -f rke2_trident_svm2_san_eco_backend.json 
+--------------+-------------------+--------------------------------------+--------+---------+
|   NAME       |  STORAGE DRIVER   |                 UUID                 | STATE  | VOLUMES |
+--------------+-------------------+--------------------------------------+--------+---------+
| svm2-san-eco | ontap-san-economy | d24a3b00-4d1f-4658-862c-c4eefec6b456 | online |       0 |
+--------------+-------------------+--------------------------------------+--------+---------+

$ tridentctl -n trident get backend
+--------------+-------------------+--------------------------------------+--------+---------+
|   NAME       |  STORAGE DRIVER   |                 UUID                 | STATE  | VOLUMES |
+--------------+-------------------+--------------------------------------+--------+---------+
| svm2-san     | ontap-san         | cdc59424-33cd-40af-9c9c-c42dc076a123 | online |       0 |
| svm2-san-eco | ontap-san-economy | d24a3b00-4d1f-4658-862c-c4eefec6b456 | online |       0 |
| svm2-nas     | ontap-nas         | 014ca078-eb62-48d2-8af6-00a34b828e13 | online |       0 |
+--------------+-------------------+--------------------------------------+--------+---------+
```

## D. Create new storage classes

Finally, let's create some storage classes to use these new Trident Backends.  
Just remember to launch the following commands against the correct Kubernete cluster.  

```bash
$ rke1
$ kubectl create -f rke1_sc_san.yaml 
storageclass.storage.k8s.io/sc-san-svm1 created
$ kubectl create -f rke1_sc_saneco.yaml 
storageclass.storage.k8s.io/sc-san-eco-svm1 created

$ kubectl get sc
NAME                    PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-san-svm1             csi.trident.netapp.io   Delete          Immediate           true                   2m29s
sc-nas-svm1 (default)   csi.trident.netapp.io   Delete          Immediate           true                   289d
sc-san-eco-svm1         csi.trident.netapp.io   Delete          Immediate           true                   3s
```

And again, let's create the storage classes for RKE2:

```bash
$ rke2
$ kubectl create -f rke2_sc_san.yaml 
storageclass.storage.k8s.io/sc-san-svm2 created
$ kubectl create -f rke2_sc_saneco.yaml 
storageclass.storage.k8s.io/sc-san-eco-svm2 created

$ kubectl get sc
NAME                    PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-san-svm2             csi.trident.netapp.io   Delete          Immediate           true                   2m29s
sc-nas-svm2 (default)   csi.trident.netapp.io   Delete          Immediate           true                   289d
sc-san-eco-svm2         csi.trident.netapp.io   Delete          Immediate           true                   3s
```

There you go! You are all set !