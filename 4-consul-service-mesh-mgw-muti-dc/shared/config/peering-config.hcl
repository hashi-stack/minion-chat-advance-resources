Kind = "exported-services"
Name = "default"
Services = [
  {
    ## The name and namespace of the service to export.
    Name      = "service-response"
    Namespace = "default"

    ## The list of peer clusters to export the service to.
    Consumers = [
      {
        ## The peer name to reference in config is the one set
        ## during the peering process.
        Peer = "cluster-01"
      }
    ]
  }
]