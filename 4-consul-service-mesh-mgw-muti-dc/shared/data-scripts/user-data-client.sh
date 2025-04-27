#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# wait until the file is copied
if [ ! -f /tmp/shared/scripts/client.sh ]; then
  echo "Waiting for client.sh to be copied..."
  while [ ! -f /tmp/shared/scripts/client.sh ]; do
    sleep 5
  done
fi

sudo mkdir -p /ops/shared
# sleep for 10s to ensure the file is copied
sleep 10
sudo cp -R /tmp/shared /ops/

sudo bash /ops/shared/scripts/client.sh "${cloud_env}" "${retry_join}"

NOMAD_HCL_PATH="/etc/nomad.d/nomad.hcl"
CLOUD_ENV="${cloud_env}"
CONSULCONFIGDIR=/etc/consul.d

# wait for consul to start
sleep 10

PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/instance-id)

# starting the application
if [ "${application_name}" = "hello-service" ]; then
  sudo touch /var/log/fake_service.log
  sudo chmod a+rw /var/log/fake_service.log

  # starting the fake service
  LISTEN_ADDR=0.0.0.0:5050 UPSTREAM_URIS=http://localhost:9090/response fake_service > /var/log/fake_service.log 2>&1 &

  # wait until the file is copied
  if [ ! -f /tmp/shared/config/hello-service.json ]; then
    echo "Waiting for hello-service.json to be copied..."
    while [ ! -f /tmp/shared/config/hello-service.json ]; do
      sleep 5
    done
  fi
  cp /tmp/shared/config/hello-service.json /ops/shared/config/hello-service.json

  sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/hello-service.json
  sed -i "s/INSTANCE_INDEX/${index}/g" /ops/shared/config/hello-service.json

  # wait until the file is copied
  if [ ! -f /tmp/shared/config/hello-service-proxy.hcl ]; then
    echo "Waiting for hello-service-proxy.hcl to be copied..."
    while [ ! -f /tmp/shared/config/hello-service-proxy.hcl ]; do
      sleep 5
    done
  fi
  cp /tmp/shared/config/hello-service-proxy.hcl /ops/shared/config/hello-service-proxy.hcl
  sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/hello-service-proxy.hcl
  sed -i "s/INSTANCE_INDEX/${index}/g" /ops/shared/config/hello-service-proxy.hcl
  sed -i "s/PROXY_PORT/21000/g" /ops/shared/config/hello-service-proxy.hcl

  sleep 10

  # Register the service with Consul
  consul services register /ops/shared/config/hello-service.json
  consul services register /ops/shared/config/hello-service-proxy.hcl
  # sudo docker run -d --name service-a-sidecar --network host consul:1.18 connect proxy -sidecar-for service-hello -admin-bind="127.0.0.1:19000"
  
  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -sidecar-for service-hello -ignore-envoy-compatibility -- -l debug > /var/log/envoy.log 2>&1 &
elif [ "${application_name}" = "response-service" ]; then
  sudo touch /var/log/fake_service.log
  sudo chmod a+rw /var/log/fake_service.log

  # starting the fake service
  LISTEN_ADDR=0.0.0.0:6060 fake_service > /var/log/fake_service.log 2>&1 &

  sleep 10

  # wait until the file is copied
  if [ ! -f /tmp/shared/config/response-service.json ]; then
    echo "Waiting for response-service.json to be copied..."
    while [ ! -f /tmp/shared/config/response-service.json ]; do
      sleep 5
    done
    cp /tmp/shared/config/response-service.json /ops/shared/config/response-service.json
  fi

  sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/response-service.json
  sed -i "s/INSTANCE_INDEX/${index}/g" /ops/shared/config/response-service.json

  # wait until the file is copied
  if [ ! -f /tmp/shared/config/response-service-proxy.hcl ]; then
    echo "Waiting for response-service-proxy.hcl to be copied..."
    while [ ! -f /tmp/shared/config/response-service-proxy.hcl ]; do
      sleep 5
    done
  fi
  sed -i "s/IP_ADDRESS/$PRIVATE_IP/g" /ops/shared/config/response-service-proxy.hcl
  sed -i "s/INSTANCE_INDEX/${index}/g" /ops/shared/config/response-service-proxy.hcl
  sed -i "s/PROXY_PORT/21000/g" /ops/shared/config/response-service-proxy.hcl

  # Register the service with Consul
  consul services register /ops/shared/config/response-service.json
  consul services register /ops/shared/config/response-service-proxy.hcl
  # sudo docker run -d --name service-a-sidecar --network host consul:1.18 connect proxy -sidecar-for service-response -admin-bind="127.0.0.1:19000"

  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -sidecar-for service-response -ignore-envoy-compatibility -- -l debug > /var/log/envoy.log 2>&1 &
elif [ "${application_name}" = "mgw-service" ]; then
  sleep 10

  # wait until the file is copied
  if [ ! -f /tmp/shared/config/api-gw.hcl ]; then
    echo "Waiting for api-gw.hcl to be copied..."
    while [ ! -f /tmp/shared/config/api-gw.hcl ]; do
      sleep 5
    done
    cp /tmp/shared/config/api-gw.hcl /ops/shared/config/api-gw.hcl
  fi

  # wait until the file is copied
  if [ ! -f /tmp/shared/config/api-gw-routes.hcl ]; then
    echo "Waiting for api-gw-routes.hcl to be copied..."
    while [ ! -f /tmp/shared/config/api-gw-routes.hcl ]; do
      sleep 5
    done
    cp /tmp/shared/config/api-gw-routes.hcl /ops/shared/config/api-gw-routes.hcl
  fi

  # creating proxy default
  sudo tee ./proxy-default.hcl<<EOF
Kind = "proxy-defaults"
Name = "global"
MeshGateway {
  Mode = "local"
}
EOF

  consul config write proxy-default.hcl

  # Register the service with Consul
  consul config write /ops/shared/config/api-gw.hcl
  consul config write /ops/shared/config/api-gw-routes.hcl

  # starting envoy
  touch /var/log/envoy.log
  chmod a+rw /var/log/envoy.log
  consul connect envoy -gateway api -register -service minion-gateway -- --log-level debug > /var/log/envoy.log 2>&1 &
else
  echo "Unknown application name: ${application_name}"
fi

# API_PAYLOAD='{
#   "Name": "'${application_name}'",
#   "ID": "'${application_name}'-'$INSTANCE_ID'",
#   "Address": "'$PUBLIC_IP'",
#   "Port": '${application_port}',
#   "Meta": {
#     "version": "1.0.0"
#   },
#   "EnableTagOverride": false,
#   "Checks": [
#     {
#       "Name": "HTTP Health Check",
#       "HTTP": "http://'$PUBLIC_IP':'${application_port}'/'${application_health_ep}'",
#       "Interval": "10s",
#       "Timeout": "1s"
#     }
#   ]
# }'

# echo $API_PAYLOAD > /tmp/api_payload.json

# # Register the service with Consul
# curl -X PUT http://${consul_ip}:8500/v1/agent/service/register \
# -H "Content-Type: application/json" \
# -d "$API_PAYLOAD"

sleep 10

# curl --request PUT --data '["Bello!", "Poopaye!", "Tulaliloo ti amo!"]' http://consul.service.consul:8500/v1/kv/minion_phrases