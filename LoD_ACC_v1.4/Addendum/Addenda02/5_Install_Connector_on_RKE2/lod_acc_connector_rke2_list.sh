rke2

echo
echo "#############################################"
echo "# Astra Connector status"
echo "#############################################"
kubectl get -n astra-connector astraconnector
echo

if [[ $(kubectl get -n astra-connector applications --ignore-not-found=true | wc -l) -ne 0 ]]; then
  echo
  echo "#############################################"
  echo "# Astra Connector: applications"
  echo "#############################################"
  kubectl get -n astra-connector applications
  echo
fi

if [[ $(kubectl get -n astra-connector snapshots --ignore-not-found=true | wc -l) -ne 0 ]]; then
  echo
  echo "#############################################"
  echo "# Astra Connector: snapshots"
  echo "#############################################"
  kubectl get -n astra-connector snaphots
  echo
fi

if [[ $(kubectl get -n astra-connector backups --ignore-not-found=true | wc -l) -ne 0 ]]; then
  echo
  echo "#############################################"
  echo "# Astra Connector: backups"
  echo "#############################################"
  kubectl get -n astra-connector backups
  echo
fi

if [[ $(kubectl get -n astra-connector schedules --ignore-not-found=true | wc -l) -ne 0 ]]; then
  echo
  echo "#############################################"
  echo "# Astra Connector: schedules"
  echo "#############################################"
  kubectl get -n astra-connector schedules
  echo
fi