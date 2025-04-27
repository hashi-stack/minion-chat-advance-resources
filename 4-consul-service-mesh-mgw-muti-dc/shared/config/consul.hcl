data_dir = "/opt/consul/data"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "IP_ADDRESS"

bootstrap_expect = 1

acl {
    enabled = true
    default_policy = "deny"
    enable_token_persistence = true
    tokens {
        initial_management = "e95b599e-166e-7d80-08ad-aee76e7ddf19"
        agent = "e95b599e-166e-7d80-08ad-aee76e7ddf19"
    }
}
#license_path = "/ops/consul/shared/license.hclic"

log_level = "INFO"

server = true
ui = true

retry_join = ["RETRY_JOIN"]

service {
    name = "minion-consul"
}

ports {
  grpc = 8502
}