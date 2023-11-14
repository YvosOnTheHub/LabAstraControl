#########################################################################################
# SCENARIO 2: Complete the lab for NFS  
#########################################################################################

**GOAL:**  
This lab is configured to provide persitent volumes based on NFS with the Trident ONTAP-NAS driver.  
As ACC 23.10 supports protecting qtree based environments (with the help of ACP), this chapter will guide you through the configuration of the Trident ONTAP-NAS-ECONOMY driver. (make sure you have gone the [lab upgrade](../../Addendum/Addenda02/) first).  

The .snapshot directory must be accessible in order for Qtree backup to be functional.  
This is achieved by setting the parameter _snapshortDir:true_ in the backend.  

If you have already gone through the scenario2 which configures iSCSI backends, you don't need to recreate the secret which we reuse here.  
```bash
$ rke1
$ kubectl create -f rke1_trident_svm1_secret.yaml
secret/ontap-svm1-secret created
$ kubectl create -f rke1_trident_svm1_nas_eco_backend.yaml
tridentbackendconfig.trident.netapp.io/backend-ontap-nas-eco created

$ tridentctl -n trident get backend
+----------+-------------------+--------------------------------------+--------+------------+---------+
|   NAME   |  STORAGE DRIVER   |                 UUID                 | STATE  | USER-STATE | VOLUMES |
+----------+-------------------+--------------------------------------+--------+------------+---------+
| svm1-nas | ontap-nas         | 6f3ae41c-a0b4-4850-9c60-a4eac0785220 | online | normal     |      15 |
| san      | ontap-san         | 93471f72-2334-46be-83de-be62723c6bc9 | online | normal     |       0 |
| san-eco  | ontap-san-economy | 41ecf87d-fdd8-49d9-9c59-888d4096eca6 | online | normal     |       0 |
| nas-eco  | ontap-nas-economy | e9b835bb-92bb-4c42-8ee3-3df904385434 | online | normal     |       0 |
+----------+-------------------+--------------------------------------+--------+------------+---------+

$ rke2
$ kubectl create -f rke2_trident_svm2_secret.yaml
secret/ontap-svm1-secret created
$ kubectl create -f rke2_trident_svm2_nas_eco_backend.yaml
tridentbackendconfig.trident.netapp.io/backend-ontap-nas-eco created

$ tridentctl -n trident get backend
+----------+-------------------+--------------------------------------+--------+------------+---------+
|   NAME   |  STORAGE DRIVER   |                 UUID                 | STATE  | USER-STATE | VOLUMES |
+----------+-------------------+--------------------------------------+--------+------------+---------+
| svm2-nas | ontap-nas         | 9093d316-e1ba-4802-89e2-b33ddd0bd013 | online | normal     |       0 |
| san      | ontap-san         | 51fe9aad-5842-4b36-ac59-cb204f329559 | online | normal     |       0 |
| san-eco  | ontap-san-economy | 4162239d-284d-4cdf-a952-a6611a538fb9 | online | normal     |       0 |
| nas-eco  | ontap-nas-economy | 6fd140ec-8fac-4833-9e08-b8d6d3e82683 | online | normal     |       0 |
+----------+-------------------+--------------------------------------+--------+------------+---------+
```

The ONTAP-NAS backends, that were originally configured in the lab, have been created with tridentctl.  
Hence they do not figure in the Trident TBC list (TridentBackendConfig CRD).  
In order to have a full integration, let's create the Kubernetes objects corresponding to this backend:

```bash
$ rke1
$ kubectl create -f rke1_trident_cluster1_secret.yaml
secret/ontap-cluster1-secret created
$ kubectl create -f rke1_trident_svm1_nas_backend.yaml
tridentbackendconfig.trident.netapp.io/backend-ontap-nas created

$ rke2
$ kubectl create -f rke2_trident_cluster3_secret.yaml
secret/ontap-cluster3-secret created
$ kubectl create -f rke2_trident_svm2_nas_backend.yaml
tridentbackendconfig.trident.netapp.io/backend-ontap-nas created
```

Both ONTAP-NAS backends are now also usable with TBC CRD:
```bash
$ rke1
$ kubectl get -n trident tbc
NAME                    BACKEND NAME   BACKEND UUID                           PHASE   STATUS
backend-ontap-nas       svm1-nas       6f3ae41c-a0b4-4850-9c60-a4eac0785220   Bound   Success
backend-ontap-nas-eco   nas-eco        e9b835bb-92bb-4c42-8ee3-3df904385434   Bound   Success
backend-ontap-san       san            93471f72-2334-46be-83de-be62723c6bc9   Bound   Success
backend-ontap-san-eco   san-eco        41ecf87d-fdd8-49d9-9c59-888d4096eca6   Bound   Success

$ rke2
$ kubectl get -n trident tbc
NAME                    BACKEND NAME   BACKEND UUID                           PHASE   STATUS
backend-ontap-nas       svm2-nas       9093d316-e1ba-4802-89e2-b33ddd0bd013   Bound   Success
backend-ontap-nas-eco   nas-eco        6fd140ec-8fac-4833-9e08-b8d6d3e82683   Bound   Success
backend-ontap-san       san            51fe9aad-5842-4b36-ac59-cb204f329559   Bound   Success
backend-ontap-san-eco   san-eco        4162239d-284d-4cdf-a952-a6611a538fb9   Bound   Success
```

Just need to create the storage classes for the ONTAP-NAS-ECONOMY backend, and you are all set:
```bash
$ rke1
$ kubectl create -f rke1_trident_svm1_san_eco_backend.yaml
tridentbackendconfig.trident.netapp.io/backend-ontap-san-eco created
$ kubectl get sc
NAME                    PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-nas-svm1 (default)   csi.trident.netapp.io   Delete          Immediate           true                   30d
storage-class-nas-eco   csi.trident.netapp.io   Delete          Immediate           true                   22h
storage-class-san       csi.trident.netapp.io   Delete          Immediate           true                   22h
storage-class-san-eco   csi.trident.netapp.io   Delete          Immediate           true                   22h

$ rke2
$ kubectl create -f rke2_trident_svm2_san_eco_backend.yaml
tridentbackendconfig.trident.netapp.io/backend-ontap-san-eco created
$ kubectl get sc
NAME                    PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-nas-svm2 (default)   csi.trident.netapp.io   Delete          Immediate           true                   30d
storage-class-nas-eco   csi.trident.netapp.io   Delete          Immediate           true                   22h
storage-class-san       csi.trident.netapp.io   Delete          Immediate           true                   22h
storage-class-san-eco   csi.trident.netapp.io   Delete          Immediate           true                   22h
```

There you go! You are all set !