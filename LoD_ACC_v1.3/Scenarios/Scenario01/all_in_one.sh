# TO RUN ON THE HOST HELPER1

echo "#######################################################################################################"
echo "UPDATING RKE1 ISCSI CONFIG"
echo "#######################################################################################################"
echo
i=0
hosts=( "cp1.rke1" "cp2.rke1" "worker1.rke1" "worker2.rke1" "worker3.rke1")
for host in "${hosts[@]}"
do
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf"
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i '2 a \    find_multipaths no' /etc/multipath.conf"
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i /iqn/s/.$/$i/ /etc/iscsi/initiatorname.iscsi"
  ssh -o "StrictHostKeyChecking no" root@$host -t "systemctl restart iscsid"
  ssh -o "StrictHostKeyChecking no" root@$host -t "systemctl restart multipathd"
  i=$((i+1))
done

rke1
kubectl get -n trident po -l app=node.csi.trident.netapp.io -o name | xargs kubectl delete -n trident


echo "#######################################################################################################"
echo "UPDATING RKE2 ISCSI CONFIG"
echo "#######################################################################################################"
echo
hosts=( "cp1.rke2" "cp2.rke2" "worker1.rke2" "worker2.rke2" "worker3.rke2")
for host in "${hosts[@]}"
do
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i 's/^\(node.session.scan\).*/\1 = manual/' /etc/iscsi/iscsid.conf"
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i '2 a \    find_multipaths no' /etc/multipath.conf"
  ssh -o "StrictHostKeyChecking no" root@$host -t "sed -i /iqn/s/.$/$i/ /etc/iscsi/initiatorname.iscsi"
  ssh -o "StrictHostKeyChecking no" root@$host -t "systemctl restart iscsid"
  ssh -o "StrictHostKeyChecking no" root@$host -t "systemctl restart multipathd"
  i=$((i+1))
done

rke2
kubectl get -n trident po -l app=node.csi.trident.netapp.io -o name | xargs kubectl delete -n trident


echo "#######################################################################################################"
echo "CONFIGURE iSCSI on CLUSTER1 (SVM 'SVM1')"
echo "#######################################################################################################"
echo

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


echo "#######################################################################################################"
echo "CONFIGURE iSCSI on CLUSTER3 (SVM 'SVM2')"
echo "#######################################################################################################"
echo

# Create one iSCSI LIF on SVM1
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

# Enable iSCSI on SVM2
curl -X POST -ku admin:Netapp1! -H "accept: application/json" -H "Content-Type: application/json" -d '{
  "enabled": true,
  "svm": { "name": "svm2" }
}' "https://cluster3.demo.netapp.com/api/protocols/san/iscsi/services"


echo "#######################################################################################################"
echo "ADD NEW TRIDENT BACKENDS & SC ON RKE1"
echo "#######################################################################################################"
echo

[ ! -f "/root/trident-installer/tridentctl" ] && cp /root/trident-installer/tridentctl /usr/bin

rke1
tridentctl -n trident create backend -f rke1_trident_svm1_san_backend.json
tridentctl -n trident create backend -f rke1_trident_svm1_san_eco_backend.json
kubectl create -f rke1_sc_san.yaml
kubectl create -f rke1_sc_saneco.yaml

echo "#######################################################################################################"
echo "ADD NEW TRIDENT BACKENDS & SC ON RKE2"
echo "#######################################################################################################"
echo

rke2
tridentctl -n trident create backend -f rke2_trident_svm1_san_backend.json
tridentctl -n trident create backend -f rke2_trident_svm1_san_eco_backend.json
kubectl create -f rke2_sc_san.yaml
kubectl create -f rke2_sc_saneco.yaml