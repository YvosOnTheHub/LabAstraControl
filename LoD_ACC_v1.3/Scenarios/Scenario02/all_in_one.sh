#!/bin/bash
# SCRIPT TO RUN ON HELPER1

<<links
https://docs.fluentd.org/how-to-guides/free-alternative-to-splunk-by-fluentd
https://docs.fluentd.org/installation/install-by-rpm
https://docs.fluentd.org/installation/before-install
https://www.elastic.co/guide/en/kibana/6.7/tutorial-load-dataset.html
links

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
echo "# - Java"
echo "# - Chronyd (ntpd)"
echo "# - Firewalld"
echo "##########################"

dnf install -y java-1.8.0-openjdk
java -version

systemctl start chronyd
systemctl stop firewalld

#ulimit -n

echo
echo "########################################"
echo "# Install & Configure ElasticSearch"
echo "########################################"

cd && mkdir elasticsearch && cd elasticsearch
curl -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.1.0.tar.gz
tar -xf elasticsearch-6.1.0.tar.gz
cd elasticsearch-6.1.0

groupadd elasticsearch
useradd elasticsearch -g elasticsearch -p elasticsearch
chown -R elasticsearch:elasticsearch /root/elasticsearch
chmod o+x /root/ /root/elasticsearch/
chgrp elasticsearch /root/elasticsearch/
su -m elasticsearch -c "cd /root/elasticsearch/elasticsearch-6.1.0 && ./bin/elasticsearch -d -p pid"
sleep 5

echo "################"
echo "# CHECK ELASTIC:"
echo "################"
curl localhost:9200

echo
echo "########################################"
echo "# Install & Configure Kibana"
echo "########################################"

cd && mkdir kibana && cd kibana
curl -O https://artifacts.elastic.co/downloads/kibana/kibana-6.1.0-linux-x86_64.tar.gz
tar -xf kibana-6.1.0-linux-x86_64.tar.gz
mv kibana-6.1.0-linux-x86_64 kibana
cd kibana
cp config/kibana.yml config/kibana.yml.bak
sed -i '/server\.host\:/s/^#//' config/kibana.yml
sed -i '/server\.host\:/s/localhost/helper1/' config/kibana.yml
./bin/kibana &
sleep 5

echo "################"
echo "# CHECK KIBANA:"
echo "################"
curl helper1:5601/status -I

echo
echo "########################################"
echo "# Install & Configure Fluentd"
echo "########################################"

cd
curl -L https://toolbelt.treasuredata.com/sh/install-redhat-td-agent3.sh | sh
cd /etc/td-agent
openssl req -new -passout pass:"netapp1" -x509 -sha256 -days 1095 -newkey rsa:2048 -keyout fluentd.key -out fluentd.crt -subj "/C=FR/ST=IdF/L=Paris/O=YvosCorp/OU=IT/CN=demo.netapp.com/emailAddress=admin@demo.netapp.com"
sudo mkdir -p /etc/td-agent/certs
sudo mv fluentd.* /etc/td-agent/certs
sudo chown td-agent:td-agent -R /etc/td-agent/certs
sudo chmod 700 /etc/td-agent/certs/
sudo chmod 400 /etc/td-agent/certs/fluentd.key
mv td-agent.conf td-agent.conf.bak

cat <<EOT >> /etc/td-agent/td-agent.conf
<source>
  @type forward
  port    24231
  bind 0.0.0.0
  @log_level error
  <security>
    self_hostname astra
    shared_key netapp
  </security>
  <transport tls>
    cert_path /etc/td-agent/certs/fluentd.crt
    private_key_path /etc/td-agent/certs/fluentd.key
    private_key_passphrase netapp1
  </transport>
  @id input_forward
</source>

<match managed-cluster.events>
  @type elasticsearch
  logstash_format true
  logstash_prefix astra
</match>
EOT

sudo systemctl start td-agent.service

<<other_possibilities
<match managed-cluster.events>
  @type elasticsearch
  logstash_format true
  <buffer>
    flush_interval 10s # for testing
  </buffer>
</match>

<match managed-cluster.events>
  @type file
  path /tmp/astra
  @id output_file
</match>
other_possibilities

echo
echo "############################################"
echo "# Create SharedKey (netapp) for Fluentd"
echo "############################################"

DATE=$(date +%Y-%m-%d'T00:00:01.000Z')
DATE7=$(date -d "1 week" +%Y-%m-%d'T00:00:01.000Z')

cat > CURL-ACC-FluentD-Cred.json << EOF
{
  "keyStore": { "sharedKey": "bmV0YXBw" },
  "keyType": "generic",
  "name": "FluentBitCredentials",
  "type": "application/astra-credential",
  "valid": "true",
  "validFromTimestamp": "$DATE",
  "validUntilTimestamp": "$DATE7",
  "version": "1.1"
}
EOF

CREATEFLUENTCRED=$(curl -k -X POST "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/credentials" \
  -H 'accept: application/astra-credential+json' -H 'Content-Type: application/astra-credential+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-FluentD-Cred.json)

FLUENTDCREDUUID=$(echo $CREATEFLUENTCRED | jq -r .id)
rm -f CURL-ACC-FluentD-Cred.json

echo
echo "############################################"
echo "# Update Fluentd configuration in ACC"
echo "############################################"

SETTINGS=$(curl -k -X GET "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/settings" -H "Authorization: Bearer $APITOKEN")
FLUENTDID=$(echo $SETTINGS | jq -c '.items[] | select(.name | endswith("fluentbitExternal"))' | jq -r .id)

cat > CURL-ACC-Fluentd-Settings.json << EOF
{
  "desiredConfig": {
    "credentialUUID": "$FLUENTDCREDUUID",
    "host": "helper1",
    "isEnabled": "true",
    "port": 24231
  },
  "type": "application/astra-setting",
  "version": "1.0"
}
EOF

curl -k -X PUT "https://astra.demo.netapp.com/accounts/$ACCOUNTID/core/v1/settings/$FLUENTDID" \
  -H 'accept: application/astra-setting+json' -H 'Content-Type: application/astra-setting+json' \
  -H "Authorization: Bearer $APITOKEN" \
  -d @CURL-ACC-Fluentd-Settings.json

rm -f CURL-ACC-Fluentd-Settings.json
sleep 5  
echo
echo "# CHECK CONFIGURATION IN ACC:"
echo "-----------------------------"
rke1
kubectl describe -n netapp-acc configmap/fluent-bit-config | grep forward -A 7 -B 1

echo
echo "##################################################################"
echo "It will take a few moments for the first events to show up in Kibana"
echo
echo "To retrieve the Elastic indices, run:"
echo "  curl http://localhost:9200/_cat/indices?v"
echo
echo "To connect to Kibana, use http://helper:5601"
echo
echo "The following will generate an error, visible in Kibana:"
echo "kubectl run nginx --image=nginx101"
echo "##################################################################"

<<schema
Following are the mappings (schema) for astra index (index pattern - astra-yyyy.mm.dd) :

{
  "application": {"type": "text"},
  "client-ip": {"type": "text"},
  "component": {"type": "keyword"},
  "error": {"type": "text"},
  "end-time": {"type": "date"},
  "latency": {"type": "long"},
  "latency-unit": {"type": "text", "index": false},
  "level": {"type": "keyword"},
  "logger-context": {"type": "text"},
  "method": {"type": "keyword"},
  "msg": {"type": "text"},
  "path": {"type": "text"},
  "protocol": {"type": "keyword"},
  "query": {"type": "text"},
  "status": {"type": "long"},
  "user-agent": {"type": "keyword"}
}

PUT /fluentd
{
 "mappings": {
  "doc": {
     "properties": {
       "application": {"type": "text"},
       "client-ip": {"type": "text"},
       "component": {"type": "keyword"},
       "error": {"type": "text"},
       "end-time": {"type": "date"},
       "latency": {"type": "long"},
       "latency-unit": {"type": "text", "index": false},
       "level": {"type": "keyword"},
       "logger-context": {"type": "text"},
       "method": {"type": "keyword"},
       "msg": {"type": "text"},
       "path": {"type": "text"},
       "protocol": {"type": "keyword"},
       "query": {"type": "text"},
       "status": {"type": "long"},
       "user-agent": {"type": "keyword"}
   }
  }
 }
}
schema