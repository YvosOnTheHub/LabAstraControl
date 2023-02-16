if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Please add the following parameters to the shell script:"
    echo " - Parameter1: ACC Account ID"
    echo " - Parameter2: ACC API Token"
    exit 0
fi

ACCOUNTID=$1
APITOKEN=$2

echo "##########################"
echo "# Prereq:"
echo "# - DNF config update"
echo "# - Java"
echo "# - Chronyd (ntpd)"
echo "# - Firewalld"
echo "##########################"

if ! grep user_agent /etc/dnf/dnf.conf ; then
sed -i '/gpgcheck/s/1/0/' /etc/dnf/dnf.conf
cat <<EOT >> /etc/dnf/dnf.conf
user_agent=curl/7.61.1
EOT
fi

