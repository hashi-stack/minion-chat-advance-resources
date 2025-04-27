ui = true
log_level = "INFO"
data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "IP_ADDRESS"
retry_join = ["RETRY_JOIN"]

acl {
  enabled = true
  tokens {
    agent = "e95b599e-166e-7d80-08ad-aee76e7ddf19"
  }
}
# license_path = "/ops/consul/shared/license.hclic"

ports {
  grpc = 8502
}