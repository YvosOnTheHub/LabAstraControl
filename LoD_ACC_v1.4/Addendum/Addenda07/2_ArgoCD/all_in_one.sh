export KUBECONFIG=/root/kubeconfigs/rke1/kube_config_cluster.yml
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --version 6.7.3 -n argocd --create-namespace -f argocd_values.yaml


curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm -f argocd-linux-amd64

ARGOCDIP=$(kubectl -n argocd get svc argocd-server -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
ARGOCDPWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
#echo "ARGOCDIP: $ARGOCDIP - ARGOCDPWD: $ARGOCDPWD"

argocd login $ARGOCDIP --username admin --password $ARGOCDPWD --insecure 

export KUBECONFIG=/root/kubeconfigs/rke2/kube_config_cluster.yml
argocd cluster add rke2 -y
