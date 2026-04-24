provides :ehvoy_bootstrap
provides :envoy_bootstrap

property :name, String, name_property: true
default_action :run

action :run do
  require 'json'
  require 'yaml'

  clusters = []
  listeners = []

  Dir.glob('/etc/envoy/generated/*.clusters.json').each do |f|
    clusters.concat(JSON.parse(::File.read(f)))
  end

  Dir.glob('/etc/envoy/generated/*.listener.json').each do |f|
    listeners << JSON.parse(::File.read(f))
  end

  bootstrap = {
    admin: {
      address: {
        socket_address: {
          address: "127.0.0.1",
          port_value: 9901,
        },
      },
    },


    static_resources: {
      clusters: clusters,
      listeners: listeners
    }
  }
  normalized = JSON.parse(JSON.generate(bootstrap))
  file '/etc/envoy/envoy.yaml' do
    content YAML.dump(normalized)
  end
end
