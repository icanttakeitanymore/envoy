# each opensource project drop supporting their apt repos lol
#
# cookbook_file '/etc/apt/keyrings/envoy-keyring.gpg' do
#   source 'keyrings/envoy-keyring.gpg'
#   owner 'root'
#   group 'root'
#   mode '0755'
#   action :create
# end

# apt_repository 'envoy' do
#   uri          'https://apt.envoyproxy.io'
#   distribution 'bookworm' # lol, they dont support their repos too
#   components   ['main']
#   signed_by      '/etc/apt/keyrings/envoy-keyring.gpg'
# end

# package 'envoy'
remote_file '/usr/local/bin/envoy' do
  source node['envoy']['url']
  checksum node['envoy']['sha256']
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end


# 1. Systemd unit
systemd_unit 'envoy.service' do
  content({
    Unit: {
      Description: 'Envoy Proxy',
      After: 'network.target'
    },
    Service: {
      ExecStartPre: '/usr/local/bin/envoy --mode validate -c /etc/envoy/envoy.yaml',
      ExecStart: '/usr/local/bin/envoy -c /etc/envoy/envoy.yaml',
      ExecReload: '/bin/kill -HUP $MAINPID',
      Restart: 'always',
      RestartSec: '5s',
      LimitNOFILE: 65536
    },
    Install: {
      WantedBy: 'multi-user.target'
    }
  })
  action [:create, :enable]
end

execute 'validate_envoy_config' do
  command '/usr/local/bin/envoy --mode validate -c /etc/envoy/envoy.yaml'
  action :nothing
  notifies :reload, 'systemd_unit[envoy.service]', :delayed
end

envoy_bootstrap 'gen_config' do
  notifies :run, 'execute[validate_envoy_config]', :immediately
end

service 'envoy' do
  service_name 'envoy'
  action :start
end