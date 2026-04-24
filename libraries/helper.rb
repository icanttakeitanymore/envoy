module EnvoyVhostCompiler
  def compile_vhost(name, cfg)
    clusters = []
    routes = []

    cfg[:routes].each do |route|
      up = route[:upstream]

      clusters << build_cluster(up)
      routes << build_route(route, up[:name])
    end

    {
      listener: build_listener(name, cfg, routes),
      clusters: clusters
    }
  end

  # ---------------- Listener ----------------

  def build_listener(name, cfg, routes)
    listen = cfg[:listen]

    {
      name: "listener_#{name}",
      address: socket_address("#{listen[:address]}:#{listen[:port]}"),
      filter_chains: [
        {
          filters: [
            {
              name: 'envoy.filters.network.http_connection_manager',
              typed_config: {
                '@type': 'type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager',
                stat_prefix: "#{name}_http",
                http_filters: [
                  {
                    name: "envoy.filters.http.router",
                    typed_config: {
                      "@type": "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router"
                    }
                  },
                ],
                route_config: {
                  virtual_hosts: [
                    {
                      name: name,
                      domains: cfg[:server_names],
                      routes: routes
                    }
                  ]
                }
              }
            }
          ],
          transport_socket: tls_socket(listen[:tls])
        }
      ]
    }
  end

  # ---------------- Route ----------------

  def build_route(route, cluster_name)
    {
      match: { prefix: route[:path] },
      route: { cluster: cluster_name }
    }
  end

  # ---------------- Cluster ----------------

  def build_cluster(up)
    cluster = {
      name: up[:name],
      type: 'STRICT_DNS',
      connect_timeout: up[:timeout] || '5s',
      dns_lookup_family: 'V4_ONLY',
      lb_policy: up[:lb_policy] || 'ROUND_ROBIN',
      load_assignment: {
        cluster_name: up[:name],
        endpoints: [
          {
            lb_endpoints: up[:endpoints].map do |ep|
              { endpoint: { address: socket_address(ep) } }
            end
          }
        ]
      }
    }

    if up[:protocol] == :https
      cluster[:transport_socket] = upstream_tls(up)
    end

    if up[:healthcheck]
      cluster[:health_checks] = [build_healthcheck(up[:healthcheck])]
    end

    cluster
  end

  # ---------------- Healthcheck ----------------

  def build_healthcheck(hc)
    {
      timeout: hc[:timeout] || '2s',
      interval: hc[:interval] || '5s',
      unhealthy_threshold: hc[:unhealthy_threshold] || 3,
      healthy_threshold: hc[:healthy_threshold] || 2,
      http_health_check: {
        path: hc[:path],
        expected_statuses: hc[:expected_statuses] || [
        { start: 200, end: 201 }
      ]
      }
      
    }
  end

  # ---------------- TLS ----------------

  def tls_socket(cfg)
    return nil unless cfg

    {
      name: 'envoy.transport_sockets.tls',
      typed_config: {
        '@type': 'type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext',
        common_tls_context: {
          tls_certificates: [
            {
              certificate_chain: { filename: cfg[:cert] },
              private_key: { filename: cfg[:key] }
            }
          ]
        }
      }
    }
  end

  def upstream_tls(up)
    return nil unless up[:tls]

    {
      name: 'envoy.transport_sockets.tls',
      typed_config: {
        '@type': 'type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext',
        sni: up[:tls][:sni]
      }
    }
  end

  def socket_address(addr)
    host, port = addr.split(':')
    {
      socket_address: {
        address: host,
        port_value: port.to_i
      }
    }
  end
end
