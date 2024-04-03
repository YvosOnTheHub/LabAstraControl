#########################################################################################
# SCENARIO 7: Protect you app with the Astra connector & ArgoCD (Tech Preview)
#########################################################################################  

Astra 24.02 released the Astra Connector which allows you to manage your applications declaratively.  
The [scenario06](../Scenario06/) already guides you through this new model, by manually creating Snapshots CR, Schedule CR, etc...  

This scenario goes a step further by integrating the protection management with a tool such as ArgoCD.  
It will guide you through the following:
- Creation of a Git repository  
- Host scenario files in this Git repository  
- Integration & Deployment of a small app (wordpress) with ArgoCD  
- Automate the scheduling of snapshots & backups by Astra Connector with ArgoCD

<p align="center"><img src="Images/scenario07_architecture.png"  width="768"></p>

The prerequisites of this lab are the following:
- Upgrade the lab to [24.02](../../Addendum/Addenda02/)  
- Install the [Astra Connector](../../Addendum/Addenda02/5_Install_Connector_on_RKE2/)  
- Install the lightweight Git repository [Gitea](../../Addendum/Addenda07/1_Gitea/)  
- Install the continuous deployment tool [ArgoCD](../../Addendum/Addenda07/2_ArgoCD/)  

Let's first create a new repository in Gitea:
```bash
curl -X POST "http://192.168.0.203:30000/api/v1/user/repos" -u lod:Netapp1! -H "accept: application/json" -H "content-type: application/json" -d '{
  "name":"scenario07",
  "description": "argocd repo"
}'
```
You will find here a folder called _Repository_ that will be used as a base. Feel free to add your own apps in there for the sake of fun!  
The following will push the data to the newly created repository. Once pushed, you can connect to the Gitea UI & see the result.  
Also, the _schedule.yaml_ file is configured to create hourly snapshots at 10 minutes from the hour.  
You may want to change that to witness automatic snapshot creation faster.  
```bash
cp -R ~/LabAstraControl/LoD_ACC_v1.4/Scenarios-ACC/Scenario07/Repository ~/
cd ~/Repository
git init
git add .
git commit -m "initial commit"
git remote add origin http://192.168.0.203:30000/lod/scenario07.git
git push -u origin master
```
<p align="center"><img src="Images/Gitea_repo_init.png"></p>

Before moving to the application management, we first need to define an AppVault (ie _a S3 Bucket_) in the Astra Connector.  
- you can create your own CR to connect to a bucket  
- you can also wait for the first app to be created, at which moment, the connector will retrieve the default Bucket from Astra Control Center  

We are going to use the first method and create our own with the help of ArgoCD.  
Note that I stored the bucket secret in Gitea, which is not really what you would do in production...  
```bash
$ rke1
$ kubectl create -f ~/LabAstraControl/LoD_ACC_v1.4/Scenarios-ACC/Scenario07/argocd_astra_appvault.yaml
application.argoproj.io/astra-appvault created
```
If all went well, you would see the app in the ArgoCD GUI:
<p align="center"><img src="Images/ArgoCD_astra_appvault.png" width="512"></p>

You can also see the result in the Astra Connector:
```bash
$ rke2
$ kubectl get -n astra-connector appvault
NAME                                                  AGE
rke2-appvault                                         2m39s
```

Let's deploy a new application. Instead of creating it with Helm, we are going to use ArgoCD.  
This could be done with the GUI or via the ArgoCD CRD, method used in the following example:  
```bash
$ rke1
$ kubectl create -f ~/LabAstraControl/LoD_ACC_v1.4/Scenarios-ACC/Scenario07/argocd_wordpress_deploy.yaml
application.argoproj.io/wordpress created
```
In a nutshell, we defined in the _argocd_wordpress_deploy.yaml_ file the following:
- the repo where the YAML manifests are stored ("ht<span>tp://</span>192.168.0.203:30000/lod/scenario07")
- the directory to use in that repo (Wordpress/App_config)
- the Kubernetes cluster where the app will be deployed (RKE2)  
- the target namespace (wpargo)  

If all went well, you would see the app in the ArgoCD GUI:
<p align="center"><img src="Images/ArgoCD_wordpress_deploy.png" width="512"></p>

As the CR was defined with an automated sync policy, the application will automatically appear on RKE2:
```bash
$ rke2
$ kubectl get -n wpargo pod,svc,pvc
NAME                                   READY   STATUS    RESTARTS   AGE
pod/wordpress-7c945b79c8-zv7sl         1/1     Running   0          3m52s
pod/wordpress-mysql-7c4d5fc78c-4xpjh   1/1     Running   0          3m52s

NAME                      TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
service/wordpress         LoadBalancer   172.28.187.240   192.168.0.234   80:32467/TCP   3m52s
service/wordpress-mysql   ClusterIP      None             <none>          3306/TCP       3m52s

NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/mysql-pvc   Bound    pvc-9dc10e4f-54a8-45fe-a7db-4765b53b6165   20Gi       RWX            sc-nas-svm2    3m52s
persistentvolumeclaim/wp-pvc      Bound    pvc-86ec7250-3566-48db-be92-107dd7e5eb88   20Gi       RWX            sc-nas-svm2    3m52s
```

Time to protect this application!  
The repo also has 2 files in the App_manage folder to create the following Astra CR:
- _application.yaml_ to define Wordpress as an application to manage with Astra  
- _schedule.yaml_ to automatically take snapshots & backups  

We defined in the _argocd_wordpress_manage.yaml_ file the following:
- the repo where the YAML manifests are stored ("ht<span>tp://</span>192.168.0.203:30000/lod/scenario07")
- the directory to use in that repo (Wordpress/App_manage)
- the Kubernetes cluster where the app will be deployed (RKE2) 
- the target namespace (astra-connector)  

```bash
$ rke1
$ kubectl create -f ~/LabAstraControl/LoD_ACC_v1.4/Scenarios-ACC/Scenario07/argocd_wordpress_manage.yaml
application.argoproj.io/wordpress-manage created
```
If all went well, you would see the app in the ArgoCD GUI:
<p align="center"><img src="Images/ArgoCD_wordpress_manage.png" width="512"></p>

Also, using the CLI you will find two new Astra CR for Wordpress:
```bash
$ rke2
$ kubectl get application,schedule -n astra-connector
NAME                                 AGE
application.astra.netapp.io/wpargo   4m49s

NAME                             AGE
schedule.astra.netapp.io/sched   4m49s
```
As the Astra Connector is linked to Astra Control Center, you can also check that Wordpress appeared in the GUI:
<p align="center"><img src="Images/ACC_wpargo.png" width="768"></p>

From there, depending on the schedule configured, you will see snapshots & backups showing up:  
```bash
$ rke2
$ kubectl get -n astra-connector snapshot,backup
NAME                                                   STATE     ERROR   AGE
snapshot.astra.netapp.io/hourly-7e1ef-20240329111000   Running           56m

NAME                                                 STATE     ERROR   AGE
backup.astra.netapp.io/hourly-7e1ef-20240329111000   Running           56m
```