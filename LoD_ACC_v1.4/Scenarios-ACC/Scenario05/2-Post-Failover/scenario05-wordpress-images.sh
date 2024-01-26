#!/bin/bash

# OPTIONAL PARAMETERS: 
# PARAMETER1: Docker hub login
# PARAMETER2: Docker hub password

if [[ $(yum info jq -y 2> /dev/null | grep Repo | awk '{ print $3 }') != "installed" ]]; then
    echo "#######################################################################################################"
    echo "Install JQ"
    echo "#######################################################################################################"
    yum install -y jq
fi

if [ $# -eq 2 ]; then
  podman login -u $1 -p $2
else
    TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
    RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

    if [[ $RATEREMAINING -lt 20 ]];then
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo "- Your anonymous login to the Docker Hub does not have many pull requests left ($RATEREMAINING). Consider using your own credentials"
      echo "---------------------------------------------------------------------------------------------------------------------------"
      echo
      echo "Please restart the script with the following parameters:"
      echo " - Parameter1: Docker hub login"
      echo " - Parameter2: Docker hub password"
      exit 0
  fi
fi

podman login -u registryuser -p Netapp1! registry.demo.netapp.com

echo
echo "##############################################"
echo "# PULL/PUSH WORDPRESS IMAGE"
echo "##############################################"
podman pull docker.io/bitnami/wordpress:5.9.3-debian-11-r5
podman tag docker.io/bitnami/wordpress:5.9.3-debian-11-r5 registry.demo.netapp.com/bitnami/wordpress:site1
podman push registry.demo.netapp.com/bitnami/wordpress:site1
podman tag docker.io/bitnami/wordpress:5.9.3-debian-11-r5 registry.demo.netapp.com/bitnami/wordpress:site2
podman push registry.demo.netapp.com/bitnami/wordpress:site2

echo
echo "##############################################"
echo "# PULL/PUSH MARIADB IMAGE"
echo "##############################################"
podman pull docker.io/bitnami/mariadb:10.5.15-debian-10-r62
podman tag docker.io/bitnami/mariadb:10.5.15-debian-10-r62 registry.demo.netapp.com/bitnami/mariadb:site1
podman push registry.demo.netapp.com/bitnami/mariadb:site1
podman tag docker.io/bitnami/mariadb:10.5.15-debian-10-r62 registry.demo.netapp.com/bitnami/mariadb:site2
podman push registry.demo.netapp.com/bitnami/mariadb:site2