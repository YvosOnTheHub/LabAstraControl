#########################################################################################
# SCENARIO ACP 02: CSI Snapshots & ONTAP-NAS-ECONOMY
#########################################################################################

It is not possible to create CSI Snapshots with the ONTAP-NAS-ECONOMY Trident driver.  
However, Astra Control Provisioner supports such snapshot, granted you cannot create a new PVC (or clone) with it.  
This simply enables Astra Control Center/Service to create a consistent backup of your stateful application.  

We will see in this scenario what you can or cannot do with such snapshot.  

Also, in order for this lab to succeed, you must have first created the ONTAP-NAS-ECONOMY Trident backend & storage class on RKE2.  
The steps to do so are described in the [Addendum04](../../Addendum/Addenda04/) chapter.  

You can find a shell script in this directory _scenario01_busybox_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 **optional** parameters, your Docker Hub login & password:

```bash
sh scenario02_busybox_pull_images.sh my_login my_password
```

## A. Prepare the environment

We will create on RKE2 an app in its own namespace _sc02busybox_.  
```bash
$ rke2
$ kubectl create -f busybox.yaml
namespace/sc02busybox created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n sc02busybox all,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-77797b84d8-2h4k2   1/1     Running   0          29s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/busybox   1/1     1            1           30s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/busybox-77797b84d8   1         1         1       30s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
persistentvolumeclaim/mydata   Bound    pvc-34c42cd5-5d24-48ca-a781-64131018a758   1Gi        RWX            sc-nas-eco-svm2   30s
```

## B. Create a CSI snapshot

Let's create a snapshot & see the result on the storage backend:  
```bash
$ kubectl create -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get -n sc02busybox vs
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              1Gi           csi-snapclass   snapcontent-4faaecba-4403-4429-802c-28cb0b78fe02   99m            100m

$ tridentctl -n trident get snapshot
+-----------------------------------------------+------------------------------------------+---------+
|                     NAME                      |                  VOLUME                  | MANAGED |
+-----------------------------------------------+------------------------------------------+---------+
| snapshot-4faaecba-4403-4429-802c-28cb0b78fe02 | pvc-34c42cd5-5d24-48ca-a781-64131018a758 | true    |
+-----------------------------------------------+------------------------------------------+---------+
```

Now, let's find out the name of the ONTAP FlexVol that contains our qtree (ie PVC):
```bash
$ kubectl get -n trident tvol $(kubectl get -n sc02busybox pvc mydata -o=jsonpath='{.spec.volumeName}') -o=jsonpath='{.config.internalID}' | awk -F '/' '{print $5}'
trident_qtree_pool_naseco_FISZHHICJE
```
Finally, let's validate through ONTAP API that our snapshot is indeed at the FlexVol level:
```bash
FLEXVOLGET=$(curl -s -X GET -ku admin:Netapp1! "https://cluster3.demo.netapp.com/api/storage/volumes?name=trident_qtree_pool_naseco_FISZHHICJE" -H "accept: application/json")
FLEXVOLUUID=$(echo $FLEXVOLGET | jq -r .records[0].uuid)
curl -s -X GET -ku admin:Netapp1! "https://cluster3.demo.netapp.com/api/storage/volumes/$FLEXVOLUUID/snapshots" -H "accept: application/json"
{
  "records": [
    {
      "uuid": "38a89d80-9957-44c4-8edb-3a759d0ca17f",
      "name": "snapshot-4faaecba-4403-4429-802c-28cb0b78fe02"
    }
  ],
  "num_records": 1
}
```
As expected, we just validated that the snapshot sits at the FlexVol level.

## C. Now what? Can you create a clone from this snapshot?  

**Answer: no.**  

Let's validate that:
```bash
$ kubectl get -f pvcfromsnap.yaml 
persistentvolumeclaim/mydata-from-snap created

$ kubectl get -n sc02busybox pvc
NAME               STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
mydata             Bound     pvc-34c42cd5-5d24-48ca-a781-64131018a758   1Gi        RWX            sc-nas-eco-svm2   18m
mydata-from-snap   Pending                                                                        sc-nas-eco-svm2   15s

$ kubectl describe -n sc02busybox pvc mydata-from-snap
...
Events:
  Type     Reason                Age               From                                                                                           Message
  ----     ------                ----              ----                                                                                           -------
  Normal   ExternalProvisioning  5s (x7 over 88s)  persistentvolume-controller                                                                    waiting for a volume to be created, either by external provisioner "csi.trident.netapp.io" or manually created by system administrator
  Normal   Provisioning          4s (x5 over 88s)  csi.trident.netapp.io_trident-controller-c97f4bc6f-ltvtw_3fcc6015-3406-43a7-a849-03fe50223963  External provisioner is provisioning volume for claim "sc02busybox/mydata-from-snap"
  Normal   ProvisioningFailed    4s (x5 over 88s)  csi.trident.netapp.io                                                                          failed to create cloned volume pvc-fa88b07f-33ea-4637-848d-cf95e0573b4c on backend svm2-nas-eco: cloning is not supported by backend type ontap-nas-economy
  Warning  ProvisioningFailed    4s (x5 over 88s)  csi.trident.netapp.io_trident-controller-c97f4bc6f-ltvtw_3fcc6015-3406-43a7-a849-03fe50223963  failed to provision volume with StorageClass "sc-nas-eco-svm2": rpc error: code = Unknown desc = failed to create cloned volume pvc-fa88b07f-33ea-4637-848d-cf95e0573b4c on backend svm2-nas-eco: cloning is not supported by backend type ontap-nas-economy

$ kubectl delete -f pvcfromsnap.yaml 
persistentvolumeclaim "mydata-from-snap" deleted
```

## D. What can you do with such snapshot ?

Astra Control Center and Astra Control Service will leverage that feature to create consistent backup for applications that run on top of qtrees.  
This is really a clear differentiator on the market...

More details about this : https://docs.netapp.com/us-en/astra-control-center/use/protect-apps.html#enable-backup-and-restore-for-ontap-nas-economy-operations

## E. What about Astra Trident ? 

As stated earlier, Trident does not support CSI Snapshots on top of Qtrees.  
What would happen if you tried to create one (example built with Trident 23.10 with ACP disabled):  
```bash
$ kubectl get -n sc02busybox pvc,vs
NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
persistentvolumeclaim/mydata   Bound    pvc-02182296-4881-4477-bbf5-dd8ceef18bdb   1Gi        RWX            sc-nas-eco-svm2   2m24s

NAME                                                     READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT                                    CREATIONTIME   AGE
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot   false        mydata                                            csi-snapclass   snapcontent-4e3d98ae-9a7e-4330-ad1b-fec8084f6b96                  2m1s

$ tridentctl -n trident logs
time="2023-12-14T09:43:19Z" level=error msg="Could not create snapshot." Method=CreateSnapshot Type=NASQtreeStorageDriver error="acp is not enabled" logLayer=core requestID=73b88a03-f8ed-46e8-bb24-4c22d14cb773 requestSource=CSI snapshotName=snapshot-4e3d98ae-9a7e-4330-ad1b-fec8084f6b96 sourceVolume=naseco_pvc_02182296_4881_4477_bbf5_dd8ceef18bdb workflow="snapshot=create"
time="2023-12-14T09:43:19Z" level=error msg="GRPC error: rpc error: code = Internal desc = failed to create snapshot snapshot-4e3d98ae-9a7e-4330-ad1b-fec8084f6b96 for volume pvc-02182296-4881-4477-bbf5-dd8ceef18bdb on backend svm2-nas-eco: acp is not enabled" logLayer=csi_frontend requestID=73b88a03-f8ed-46e8-bb24-4c22d14cb773 requestSource=CSI
```

As you can see, the snapshot is listed as _READYTOUSE: false_, or said differently, its creation failed.  
The Trident logs clearly display that this is only supported with ACP enabled.  

## Optional Cleanup

```bash
$ kubectl delete ns sc02busybox
namespace "sc02busybox" deleted
```