# function that displays the content of a connector CR only if there is something to display
display_content_cr() {
    crname=$1

    if [[ $(kubectl get -n astra-connector $crname --ignore-not-found=true | wc -l) -ne 0 ]]; then
        echo
        echo "#############################################"
        echo "# Astra Connector: $crname"
        echo "#############################################"
        kubectl get -n astra-connector $crname
    fi
}


# make sure you are on the correct cluster
export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml

echo
echo "#############################################"
echo "# Astra Connector status"
echo "#############################################"
kubectl get -n astra-connector astraconnector

# retrieve list of CR & put it in an array
getcr=(`kubectl get crd -o name | grep astra | awk -F "\n" '{print $1}'`)

# parse the array & display content if it exists
for cr in ${getcr[@]}
do
    crname=$(echo $cr | awk -F '/' '{print $2}' | awk -F '.' '{print $1}')
    if [ $crname != "astraconnectors" ]; then
        display_content_cr "$crname"
    fi
done