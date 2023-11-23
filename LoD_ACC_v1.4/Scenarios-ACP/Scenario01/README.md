#########################################################################################
# SCENARIO ACP 01: In-place snapshot restore
#########################################################################################

Astra Control Provisioner 23.10 introduced the possibility to perform an in-place CSI snapshot restore.  

This chapter will lead you in the management of snapshots with a simple lightweight container BusyBox.

**In-place snapshot restore can only be achieved by following these requirements**:
- the PVC must be disconnected to its POD for the restore to succeed  
- only the newest CSI Snapshot can be restored

You can find a shell script in this directory _scenario06_busybox_pull_images.sh_ to pull images utilized in this scenario if needed. It uses 2 **optional** parameters, your Docker Hub login & password:

```bash
sh scenario06_busybox_pull_images.sh my_login my_password
```

## A. Prepare the environment

We will create on RKE2 an app in its own namespace _sc06busybox_ (also very useful to clean up everything).   
```bash
$ rke2
$ kubectl create -f busybox.yaml
namespace/sc06busybox created
persistentvolumeclaim/mydata created
deployment.apps/busybox created

$ kubectl get -n sc06busybox all,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-77797b84d8-5kq29   1/1     Running   0          21s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/busybox   1/1     1            1           21s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/busybox-77797b84d8   1         1         1       21s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-4ec60504-70d2-42dd-8c5a-f90e9ae2cf71   1Gi        RWX            sc-nas-svm2    21s
```

## B. Create a snapshot

Before doing so, let's create a file in our PVC, that will be deleted once the snapshot is created.  
That way, there is a difference between the current filesystem & the snapshot content.  

```bash
$ kubectl exec -n sc06busybox $(kubectl get pod -n sc06busybox -o name) -- df -h /data
Filesystem                Size      Used Available Use% Mounted on
svm2.demo.netapp.com:/trident_pvc_4ec60504_70d2_42dd_8c5a_f90e9ae2cf71
                          1.0G    256.0K   1023.8M   0% /data

$ kubectl exec -n sc06busybox $(kubectl get pod -n sc06busybox -o name) -- touch /data/test.txt
$ kubectl exec -n sc06busybox $(kubectl get pod -n sc06busybox -o name) -- ls -l /data/test.txt
-rw-r--r--    1 nobody       nobody            0 Nov 17 07:35 /data/test.txt
$ kubectl exec -n sc06busybox $(kubectl get pod -n sc06busybox -o name) -- sh -c 'echo "Check out Astra Control Provisioner !" > /data/test.txt'
$ kubectl exec -n sc06busybox $(kubectl get pod -n sc06busybox -o name) -- more /data/test.txt
Check out Astra Control Provisioner!
```
Now, we can proceed with the snapshot creation
```bash
$ kubectl create -f pvc-snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/mydata-snapshot created

$ kubectl get volumesnapshot -n sc06busybox
NAME              READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot   true         mydata                              268Ki         csi-snapclass   snapcontent-e7867974-22c2-4e94-8f64-461a48fb3c13   19s            10s
```
Your snapshot has been created !  

Let's delete the file we created earlier, before restoring the snapshot.  
```bash
kubectl exec -n sc06busybox $(kubectl get pod -n sc06busybox -o name) -- rm -f /data/test.txt
```

## C. Perform an in-place restore of the data.

When it comes to data recovery, there are many ways to do so. If you want to recover only one file, you could browser through the .snapshot folders (if accessible) & copy/paste what you need. However, for a large dataset, copying everything will take a long time. In-place restore will benefit from the ONTAP Snapshot Restore feature, which takes only a couple of seconds whatever size the volume is!  

In order to use this feature, the volume needs to be detached from its pods.  
Since we are using a deployment object, we can just scale it down to 0:  
```bash
$ kubectl scale -n sc06busybox deploy busybox --replicas=0
deployment.apps/busybox scaled
$ kubectl get -n sc06busybox pod
No resources found in sc06busybox namespace.
```

In-place restore will be performed by created a TASR objet ("TridentActionSnapshotRestore"):  
```bash
$ kubectl create -f snapshot-restore.yaml
tridentactionsnapshotrestore.trident.netapp.io/mydatarestore created
$ kubectl get -n sc06busybox tasr -o=jsonpath='{.items[0].status.state}'; echo
Succeeded
```

We can now restart the pod, and browse through the PVC content.  
If you look at the files this POD has access to (the PVC), you will see that the *lost data* (file: test.txt) is back!
```bash
$ kubectl scale -n sc06busybox deploy busybox --replicas=1
deployment.apps/busybox scaled

$ kubectl get -n sc06busybox pod
NAME                       READY   STATUS    RESTARTS   AGE
busybox-77797b84d8-6jt5r   1/1     Running   0          10s

$ kubectl exec -n sc06busybox $(kubectl get pod -n sc06busybox -o name) -- ls -l /data/
total 0
-rw-r--r--    1 nobody   nobody          38 Nov 17 07:36 test.txt
$ kubectl exec -n sc06busybox $(kubectl get pod -n sc06busybox -o name) -- more /data/test.txt
Check out Astra Control Provisioner!
```
Tadaaa, you have restored the whole snapshot in one shot!  

## D. Error use cases: multiple CSI Snapshots

Let's take the same application, but with several CSI Snapshots:
```bash
$ kubectl get -n sc06busybox vs
NAME               READYTOUSE   SOURCEPVC   SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS   SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mydata-snapshot1   true         mydata                              268Ki         csi-snapclass   snapcontent-c369f8a8-d837-4d06-90f4-0d1eb4d3b8a0   19h            19h
mydata-snapshot2   true         mydata                              492Ki         csi-snapclass   snapcontent-1c22ba03-7f32-4ae2-8771-5e5ccb7d28c1   19h            19h
mydata-snapshot3   true         mydata                              708Ki         csi-snapclass   snapcontent-12938d6d-faea-4495-804d-aaa96c38977b   19h            19h
```

_mydata-snapshot3_ being the newest one, what happens if you try to restore the second one.  
It will fail with an explicit message in the logs or in the description of the TASR object:  
```bash
$ kubectl create -f snapshot-restore.yaml
tridentactionsnapshotrestore.trident.netapp.io/mydatarestore created

$ kubectl get -n sc06busybox tasr -o=jsonpath='{.items[0].status}' | jq
{
  "completionTime": "2023-11-23T10:00:37Z",
  "message": "volume snapshot mydata-snapshot2 is not the newest snapshot of PVC sc06busybox/mydata",
  "state": "Failed"
}

$ kubectl delete -f snapshot-restore.yaml 
tridentactionsnapshotrestore.trident.netapp.io "mydatarestore" deleted
```

## E. Error use cases: PVC attached to a POD

If you try to restore a CSI snapshot that is attached to a POD, it will also fail with an explicit message in the logs.  
You first need to scale down the POD that attaches the PVC for the restore operation to succeed:  
```bash
$ kubect get -n sc06busybox pod,pvc
NAME                           READY   STATUS    RESTARTS   AGE
pod/busybox-77797b84d8-hlkhx   1/1     Running   0          15s

NAME                           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/mydata   Bound    pvc-d6e03d66-759f-4c0e-a5e6-637bce4c9d55   1Gi        RWX            sc-nas-svm2    19h

$ kubectl create -f snapshot-restore.yaml
tridentactionsnapshotrestore.trident.netapp.io/mydatarestore created

$ kubectl get -n sc06busybox tasr -o=jsonpath='{.items[0].status}' | jq
{
  "completionTime": "2023-11-23T10:16:14Z",
  "message": "cannot restore attached volume to snapshot",
  "startTime": "2023-11-23T10:16:14Z",
  "state": "Failed"
}

$ kubectl delete -f snapshot-restore.yaml 
tridentactionsnapshotrestore.trident.netapp.io "mydatarestore" deleted
```

## Optional Cleanup

```bash
$ kubectl delete ns sc06busybox
namespace "sc06busybox" deleted
```