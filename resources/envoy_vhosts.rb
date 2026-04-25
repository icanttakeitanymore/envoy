provides :envoy_vhosts
provides :envoy_vhosts

property :name, String, name_property: true
default_action :run

action :run do
  extend EnvoyVhostCompiler

  compiled = compile_vhost(new_resource.name, node['envoy']['vhosts'][new_resource.name.to_sym])

  directory '/etc/envoy/generated' do
    recursive true
  end

  file "/etc/envoy/generated/#{new_resource.name}.listener.json" do
    content JSON.pretty_generate(compiled[:listener])
    mode '0644'
  end

  file "/etc/envoy/generated/#{new_resource.name}.clusters.json" do
    content JSON.pretty_generate(compiled[:clusters])
    mode '0644'
  end
end
