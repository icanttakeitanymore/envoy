default['envoy']['url'] = 'https://github.com/envoyproxy/envoy/releases/download/v1.38.0/envoy-1.38.0-linux-x86_64'
default['envoy']['sha256'] = 'cca312a7c3f91852f2849995c895130c59842e21ba787dc90bafa4026d6c5ecc'

=begin
example:

default['envoy']['vhosts'] = {
  openbao: {
    server_names: [
      'vault.east.local',
      '01.vault.east.local',
      '02.vault.east.local',
      '03.vault.east.local'
    ],

    listen: {
      address: '0.0.0.0',
      port: 443,
      tls: {
        cert: '/etc/openbao/cert.pem',
        key: '/etc/openbao/key.pem'
      }
    },

    routes: [
      {
        path: '/',
        upstream: {
          name: 'vault_cluster',
          protocol: :https,
          # lb_policy: 'RING_HASH',
          endpoints: [
            '01.vault.east.local:8200',
            '02.vault.east.local:8200',
            '03.vault.east.local:8200'
          ],

          tls: {
            sni: 'openbao.east.local',
          },

          timeout: '10s',

          healthcheck: {
            type: :http,
            path: '/v1/sys/health',
            interval: '5s',
            timeout: '2s',
            unhealthy_threshold: 3,
            healthy_threshold: 2,
            expected_statuses: [
                { start: 200, end: 201 },
                { start: 429, end: 430 } # lol
            ]
          }
        }
      }
    ]
  }
}
=end
