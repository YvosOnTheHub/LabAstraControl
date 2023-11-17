#########################################################################################
# SCENARIO 06: In-place snapshot restore
#########################################################################################

Astra Control Provisioner 23.10 introduced the possibility to perform an in-place CSI snapshot restore.  

This chapter will lead you in the management of snapshots with a simple lightweight container BusyBox.

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

## Optional Cleanup

```bash
$ kubectl delete ns sc06busybox
namespace "sc06busybox" deleted
```