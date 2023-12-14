#########################################################################################
# SCENARIO 2: Deploying more wordpress apps to test all possible storage classes  
#########################################################################################

This lab only comes with ONTAP-NAS deployed apps.  
You may want to test other Trident drivers to see the differences with all the possibilities.  

The [Addenda03](../../Addendum/Addenda03/) & [Addenda04](../../Addendum/Addenda04/) can be used to:
- configure iSCSI on the whole stack (storage & worker nodes)
- create ONTAP-SAN & ONTAP-SAN-ECONOMY backends
- create a ONTAP-NAS-ECONOMY backend

With all the choices, you can also test:
- The migration of an app between 2 storage classes
- Backup&Restore of Qtree based apps (ONTAP-NAS-ECONOMY)

The following will deploy on RKE2 3 new instances of Wordpress:
- with ONTAP-SAN & RWO access mode  
- with ONTAP-SAN-ECONOMY & RWO access mode  
- with ONTAP-NAS-ECONOMY & RWX access mode

```bash
rke2
helm install wpsan bitnami/wordpress --namespace wpsan --create-namespace --set wordpressUsername=admin,wordpressPassword=astra,global.storageClass=sc-san-svm2

helm install wpsaneco bitnami/wordpress --namespace wpsaneco --create-namespace --set wordpressUsername=admin,wordpressPassword=astra,global.storageClass=sc-san-eco-svm2

helm install wpnaseco bitnami/wordpress --namespace wpnaseco --create-namespace -f apps/rke2_wordpress_naseco.yaml
```