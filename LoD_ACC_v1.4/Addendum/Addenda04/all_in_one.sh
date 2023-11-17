# TO RUN ON THE HOST HELPER1

echo "#######################################################################################################"
echo "ADD NEW TRIDENT BACKENDS & SC ON RKE1"
echo "#######################################################################################################"
echo

[ -f "/root/trident-installer/tridentctl" ] && cp /root/trident-installer/tridentctl /usr/bin

export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
if [ $(kubectl -n trident get secret | grep -e 'ontap-svm1-secret' | wc -l) -eq 1 ]; then kubectl create -f rke1_trident_svm1_secret.yaml; fi
kubectl create -f rke1_trident_cluster1_secret.yaml
kubectl create -f rke1_trident_svm1_nas_backend.yaml
kubectl create -f rke1_trident_svm1_nas_eco_backend.yaml
kubectl create -f rke1_sc_naseco.yaml

echo "#######################################################################################################"
echo "ADD NEW TRIDENT BACKENDS & SC ON RKE2"
echo "#######################################################################################################"
echo

export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
if [ $(kubectl -n trident get secret | grep -e 'ontap-svm2-secret' | wc -l) -eq 1 ]; then kubectl create -f rke2_trident_svm2_secret.yaml; fi
kubectl create -f rke2_trident_cluster3_secret.yaml
kubectl create -f rke2_trident_svm2_nas_backend.yaml
kubectl create -f rke2_trident_svm2_nas_eco_backend.yaml
kubectl create -f rke2_sc_naseco.yaml