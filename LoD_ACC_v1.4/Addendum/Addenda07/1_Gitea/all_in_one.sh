export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml

helm repo add gitea-charts https://dl.gitea.com/charts/
helm install gitea gitea-charts/gitea --version 10.1.3 -n gitea --create-namespace -f gitea_values.yaml

git config --global user.email lod.demo.netapp.com
git config --global user.name "lod"
git config --global credential.helper store
git config --global alias.adcom '!git add -A && git commit -m'
git config --global push.default simple