#!/usr/bin/ruby
#
# This is a relatively simple, stupid script that creates
# a host and service graph based on cross-host dependencies
# defined in individual node graphs.

require 'puppet'
require 'net/http'
require 'cgi'

Puppet[:confdir] = "/Users/luke/etc/puppet"
Puppet[:vardir] = "/Users/luke/var/puppet"

# Create a hash of each host, and the services
# associated with that host.
def find_services_by_host(type = nil, title = nil)
  http = Net::HTTP.new("localhost", 8080)
  query = nil
  if type.nil? and title.nil?
    query = '["=", ["node", "active"], true]'
  elsif title.nil?
    query = '["=", "type", "%s"]' % [type]
  else
    query = '["and", ["=", "type", "%s"], ["=", "title", "%s"]]' % [type, title]
  end

  # Find all resources in PuppetDB
  response = http.get("/resources?query=%s" % CGI.escape(query), { "Accept" => 'application/json'})

  json = response.body

  data = PSON.parse(json)
  return nil if data.empty?

  # Collect those resources by host name
  hosts = {}
  data.collect do |hash|
    hosts[hash["certname"]] ||= []
    next unless params = hash["parameters"]
    resource = Puppet::Resource.new(hash["type"], hash["title"])
    params.each do |param, value|
      resource[param] = value
    end
    hosts[hash["certname"]] << resource
  end
  hosts
end

# Given a hash of each host and the services on it,
# use the dependencies to build a graph.
def build_environment_graph(services_by_host)
  catalog = Puppet::Resource::Catalog.new

  sources = {}
  dests = {}

  services_by_host.each do |host, resources|
    node_resource = Puppet::Resource.new("node", host)
    catalog.add_resource node_resource

    reshash = {}
    resources.each { |r| reshash[r.ref] = r }

    resources.each do |resource|
      if produces = resource["produce"]
        unless prodres = reshash[produces]
          raise "Could not find capability #{produces} produced by #{resource}"
        end

        # We want this to be unique in the catalog, but the target of the
        # edge might have already added it
        if existing = catalog.resource(prodres.ref)
          # Make sure it's not a target, only a source
          catalog.edges.each do |edge|
            next unless edge.target == prodres
            raise "Capability #{prodres} is already in the catalog, seems to be produced by #{edge.source}"
          end
        else
          catalog.add_resource prodres
        end
        catalog.add_edge(node_resource, prodres)
        puts "Added edge from #{node_resource} to #{prodres}"
      end
      if consumes = resource["consume"]
        unless conres = reshash[consumes]
          raise "Could not find capability #{consumes} consumed by #{resource}"
        end
        catalog.add_resource(conres) unless catalog.resource(conres.ref)
        catalog.add_edge(conres, node_resource)
        puts "Added edge from #{conres} to #{node_resource}"
      end
    end
  end

  catalog
end


services_by_host = find_services_by_host()
catalog = build_environment_graph(services_by_host)
file = File.expand_path("~/Desktop/hosts.dot")

puts "Printing dot to #{file}"
File.open(file, "w") { |f| f.print catalog.to_dot }
