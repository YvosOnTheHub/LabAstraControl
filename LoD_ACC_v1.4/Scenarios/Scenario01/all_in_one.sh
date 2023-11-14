# TO RUN ON THE HOST HELPER1

echo
echo "#######################################################################################################"
echo "UPDATING RKE1 ISCSI CONFIG"
echo "#######################################################################################################"
i=0
hosts=( "cp1.rke1" "cp2.rke1" "cp3.rke1" )
for host in "${hosts[@]}"
do
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf"
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i '2 a \    find_multipaths no' /etc/multipath.conf"
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i /iqn/s/.$/$i/ /etc/iscsi/initiatorname.iscsi"
  ssh -o "StrictHostKeyChecking no" root@$host -t "systemctl restart iscsid"
  ssh -o "StrictHostKeyChecking no" root@$host -t "systemctl restart multipathd"
  i=$((i+1))
done

export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
kubectl get -n trident po -l app=node.csi.trident.netapp.io -o name | xargs kubectl delete -n trident
sleep 5

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '7/7' | wc -l) -ne 5 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "UPDATING RKE2 ISCSI CONFIG"
echo "#######################################################################################################"
hosts=( "cp1.rke2" "cp2.rke2" "cp3.rke2" )
for host in "${hosts[@]}"
do
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf"
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i '2 a \    find_multipaths no' /etc/multipath.conf"
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i /iqn/s/.$/$i/ /etc/iscsi/initiatorname.iscsi"
  ssh -o "StrictHostKeyChecking no" root@$host -t "systemctl restart iscsid"
  ssh -o "StrictHostKeyChecking no" root@$host -t "systemctl restart multipathd"
  i=$((i+1))
done

export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
kubectl get -n trident po -l app=node.csi.trident.netapp.io -o name | xargs kubectl delete -n trident
sleep 5

frames="/ | \\ -"
while [ $(kubectl get -n trident pod | grep Running | grep -e '1/1' -e '2/2' -e '7/7' | wc -l) -ne 5 ]; do
    for frame in $frames; do
        sleep 0.5; printf "\rWaiting for Trident to be ready $frame" 
    done
done

echo
echo "#######################################################################################################"
echo "CONFIGURE iSCSI on CLUSTER1 (SVM 'SVM1')"
echo "#######################################################################################################"

# Create the first iSCSI LIF on SVM1
curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "ip": { "address": "192.168.0.245", "netmask": "24" },
  "location": {
    "home_port": {
      "name": "e0d",
      "node": { "name": "cluster1-01" }
    }
  },
  "name": "iSCSIlif1",
  "scope": "svm",
  "service_policy": { "name": "default-data-iscsi" },
  "svm": { "name": "svm1" }
}' "https://cluster1.demo.netapp.com/api/network/ip/interfaces"


# Create the second iSCSI LIF on SVM1
curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "ip": { "address": "192.168.0.246", "netmask": "24" },
  "location": {
    "home_port": {
      "name": "e0d",
      "node": { "name": "cluster1-02" }
    }
  },
  "name": "iSCSIlif2",
  "scope": "svm",
  "service_policy": { "name": "default-data-iscsi" },
  "svm": { "name": "svm1" }
}' "https://cluster1.demo.netapp.com/api/network/ip/interfaces"

# Enable iSCSI on SVM1
curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "enabled": true,
  "svm": { "name": "svm1" }
}' "https://cluster1.demo.netapp.com/api/protocols/san/iscsi/services"

echo
echo "#######################################################################################################"
echo "CONFIGURE iSCSI on CLUSTER3 (SVM 'SVM2')"
echo "#######################################################################################################"

# Create the first iSCSI LIF on SVM2
curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "ip": { "address": "192.168.0.247", "netmask": "24" },
  "location": {
    "home_port": {
      "name": "e0d",
      "node": { "name": "cluster3-01" }
    }
  },
  "name": "iSCSIlif1",
  "scope": "svm",
  "service_policy": { "name": "default-data-iscsi" },
  "svm": { "name": "svm2" }
}' "https://cluster3.demo.netapp.com/api/network/ip/interfaces"

# Create the second iSCSI LIF on SVM2
curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "ip": { "address": "192.168.0.248", "netmask": "24" },
  "location": {
    "home_port": {
      "name": "e0d",
      "node": { "name": "cluster3-01" }
    }
  },
  "name": "iSCSIlif2",
  "scope": "svm",
  "service_policy": { "name": "default-data-iscsi" },
  "svm": { "name": "svm2" }
}' "https://cluster3.demo.netapp.com/api/network/ip/interfaces"

# Enable iSCSI on SVM2
curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "enabled": true,
  "svm": { "name": "svm2" }
}' "https://cluster3.demo.netapp.com/api/protocols/san/iscsi/services"

echo
echo "#######################################################################################################"
echo "ADD NEW TRIDENT BACKENDS & SC ON RKE1"
echo "#######################################################################################################"

[ -f "/root/trident-installer/tridentctl" ] && cp /root/trident-installer/tridentctl /usr/bin

export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
if [ $(kubectl -n trident get secret | grep -e 'ontap-svm1-secret' | wc -l) -eq 1 ]; then kubectl create -f rke1_trident_svm1_secret.yaml; fi
kubectl create -f rke1_trident_svm1_san_backend.yaml
kubectl create -f rke1_trident_svm1_san_eco_backend.yaml
kubectl create -f rke1_sc_san.yaml
kubectl create -f rke1_sc_saneco.yaml

echo
echo "#######################################################################################################"
echo "ADD NEW TRIDENT BACKENDS & SC ON RKE2"
echo "#######################################################################################################"

export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
if [ $(kubectl -n trident get secret | grep -e 'ontap-svm2-secret' | wc -l) -eq 1 ]; then kubectl create -f rke2_trident_svm2_secret.yaml; fi
kubectl create -f rke2_trident_svm2_san_backend.yaml
kubectl create -f rke2_trident_svm2_san_eco_backend.yaml
kubectl create -f rke2_sc_san.yaml
kubectl create -f rke2_sc_saneco.yaml