#!/opt/puppetlabs/puppet/bin/ruby

require 'puppet'

def start(provider)
  if provider.status == :running
    { status: 'in_sync' }
  else
    provider.start
    { status: 'started' }
  end
end

def stop(provider)
  if provider.status == :stopped
    { status: 'in_sync' }
  else
    provider.stop
    { status: 'stopped' }
  end
end

def restart(provider)
  provider.restart

  { status: 'restarted' }
end

def status(provider)
  { status: provider.status, enabled: provider.enabled? }
end

def enable(provider)
  if provider.enabled?.to_s == 'true'
    { status: 'in_sync' }
  else
    provider.enable
    { status: 'enabled' }
  end
end

def disable(provider)
  if provider.enabled?.to_s == 'true'
    provider.disable
    { status: 'disabled' }
  else
    { status: 'in_sync' }
  end
end

def check_catalog(service_name)
  Puppet.initialize_settings
  catalog_file = File.join(Puppet.settings[:client_datadir], 'catalog', "#{Puppet.settings[:certname]}.json")
  catalog      = JSON.parse(File.read(catalog_file))
  p            = catalog['resources'].select { |r| r['type'] == 'Service' and r['title'] == service_name }.first.dig('parameters')
  if p
    # Convert keys to symbols
    p_to_sym = p.map { |k,v| [k.to_sym,v] }.flatten
    Hash[*p_to_sym]
  else
    {}
  end
end

params = JSON.parse(STDIN.read)
name = params['name']
provider = params['provider']
action = params['action']
use_catalog = params['use_catalog'] || 'no'

# Testing
#name = 'foo'
#provider = false
#action = 'restart'
#use_catalog = 'yes'

opts = { name: name }
opts[:provider] = provider if provider

if use_catalog == 'yes'
  managed_parameters = check_catalog(name)
  opts.merge!(managed_parameters)
end

begin
  provider = Puppet::Type.type(:service).new(opts).provider

  result = send(action, provider)
  puts result.to_json
  exit 0
rescue Puppet::Error => e
  puts({ status: 'failure',
         _error: { msg: e.message,
                   kind: "puppet_error",
                   details: {}
                 }
       }.to_json)
  exit 1
end
