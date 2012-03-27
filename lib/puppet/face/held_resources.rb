require 'puppet/face'
require 'puppet/resource/held'

Puppet::Face.define(:held_resources, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage Held resources.  Should be merged with 'puppet resource'."

  action(:hold) do
    summary "Stop a resource from being managed"
    arguments "<resource reference> ..."
    returns <<-'EOT'
      True if successful, false otherwise.
    EOT
    description <<-'EOT'
      Tells Puppet to stop managing a given resource.  You will get
      warnings on every held resource, but never changes.
    EOT
    examples <<-'EOT'
      Don't manage the /etc/motd file:

      $ puppet held_resources hold 'File[/etc/motd]'
    EOT

    when_invoked do |*args|
      options = args.pop
      holder = Puppet::Resource::Held.new
      holder.load
      args.each do |r|
        holder.hold(r)
      end
      holder.write
      nil
    end
  end

  action(:release) do
    summary "Begin managing a resource again."
    arguments "<resource reference> ..."
    returns <<-'EOT'
      True if successful, false otherwise.
    EOT
    description <<-'EOT'
      Tells Puppet to start managing a given resource again.  This
      doesn't change anything on the machine, it just tells Puppet
      that it's ok to change this resource.
    EOT
    examples <<-'EOT'
      Starting managing /etc/motd again:

      $ puppet held_resources release 'File[/etc/motd]'
    EOT

    when_invoked do |*args|
      options = args.pop
      holder = Puppet::Resource::Held.new
      holder.load
      args.each do |r|
        holder.release(r)
      end
      holder.write
      nil
    end
  end

  action(:list) do
    summary "List all held resources"
    returns <<-'EOT'
      A list of resource references.
    EOT
    description <<-'EOT'
      Provides a complete list of all held resources.
    EOT
    examples <<-'EOT'
      List held resources:

      $ puppet held_resources list:
    EOT

    when_invoked do |*args|
      options = args.pop
      holder = Puppet::Resource::Held.new
      holder.load
      holder.held
    end

    when_rendering :console do |value|
      if value.empty? then
        ""
      else
        value.join("\n")
      end
    end
  end
end
