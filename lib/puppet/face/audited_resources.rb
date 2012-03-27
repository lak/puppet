require 'puppet/face'
require 'puppet/resource/audited'

Puppet::Face.define(:audited_resources, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Manage audited resources.  Should be merged with 'puppet resource'."

  action(:audit) do
    summary "Report on a given resource when auditing."
    arguments "<resource reference> ..."
    returns <<-'EOT'
      True if successful, false otherwise.
    EOT
    description <<-'EOT'
      A tool to allow users to inform administrators that a resource
      is worth auditing, as they're changing it themselves.
    EOT
    examples <<-'EOT'
      audit the /etc/motd file:

      $ puppet audited_resources audit 'File[/etc/motd]'
    EOT

    when_invoked do |*args|
      options = args.pop
      auditor = Puppet::Resource::Audited.new
      auditor.load
      args.each do |r|
        auditor.audit(r)
      end
      auditor.write
      nil
    end
  end

  action(:unaudit) do
    summary "Stop auditing a resource."
    arguments "<resource reference> ..."
    returns <<-'EOT'
      True if successful, false otherwise.
    EOT
    description <<-'EOT'
      Tells Puppet to stop auditing a resource.  It will no
      longer be audited, unless the sysadmin has added it to
      the central list.
    EOT
    examples <<-'EOT'
      Stop auditing /etc/motd:

      $ puppet audited_resources unaudit 'File[/etc/motd]'
    EOT

    when_invoked do |*args|
      options = args.pop
      auditor = Puppet::Resource::Audited.new
      auditor.load
      args.each do |r|
        auditor.unaudit(r)
      end
      auditor.write
      nil
    end
  end

  action(:list) do
    summary "List all audited resources"
    returns <<-'EOT'
      A list of resource references.
    EOT
    description <<-'EOT'
      Provides a complete list of all audited resources.
    EOT
    examples <<-'EOT'
      List audited resources:

      $ puppet audited_resources list
    EOT

    when_invoked do |*args|
      options = args.pop
      auditor = Puppet::Resource::Audited.new
      auditor.load
      auditor.audited
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
