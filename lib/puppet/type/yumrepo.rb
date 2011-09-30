# Description of yum repositories

require 'puppet/util/inifile'

module Puppet
  # A property for one entry in a .ini-style file
  class IniProperty < Puppet::Property
    def insync?(is)
      # A should property of :absent is the same as nil
      if is.nil? && should == :absent
        return true
      end
      super(is)
    end

    def sync
      result = set(self.should)
      if should == :absent
          provider.section[inikey] = nil
      else
          provider.section[inikey] = should
      end
      result
    end

    def retrieve
      provider.section[inikey]
    end

    def inikey
      name.to_s
    end

    # Set the key associated with this property to KEY, instead
    # of using the property's NAME
    def self.inikey(key)
      # Override the inikey instance method
      # Is there a way to do this without resorting to strings ?
      # Using a block fails because the block can't access
      # the variable 'key' in the outer scope
      self.class_eval("def inikey ; \"#{key.to_s}\" ; end")
    end

  end

  # Doc string for properties that can be made 'absent'
  ABSENT_DOC="Set this to 'absent' to remove it from the file completely"

  newtype(:yumrepo) do
    @doc = "The client-side description of a yum repository. Repository
      configurations are found by parsing `/etc/yum.conf` and
      the files indicated by the `reposdir` option in that file 
      (see yum.conf(5) for details)

      Most parameters are identical to the ones documented
      in yum.conf(5)

      Continuation lines that yum supports for example for the
      baseurl are not supported. No attempt is made to access
      files included with the **include** directive"

    newparam(:name) do
      desc "The name of the repository.  This corresponds to the
        repositoryid parameter in yum.conf(5)."
      isnamevar
    end

    newproperty(:descr, :parent => Puppet::IniProperty) do
      desc "A human readable description of the repository.
        This corresponds to the name parameter in yum.conf(5).
        #{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(/.*/) { }
      inikey "name"
    end

    newproperty(:mirrorlist, :parent => Puppet::IniProperty) do
      desc "The URL that holds the list of mirrors for this repository.
        #{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      # Should really check that it's a valid URL
      newvalue(/.*/) { }
    end

    newproperty(:baseurl, :parent => Puppet::IniProperty) do
      desc "The URL for this repository.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      # Should really check that it's a valid URL
      newvalue(/.*/) { }
    end

    newproperty(:enabled, :parent => Puppet::IniProperty) do
      desc "Whether this repository is enabled or disabled. Possible
        values are '0', and '1'.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{(0|1)}) { }
    end

    newproperty(:gpgcheck, :parent => Puppet::IniProperty) do
      desc "Whether to check the GPG signature on packages installed
        from this repository. Possible values are '0', and '1'.
        \n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{(0|1)}) { }
    end

    newproperty(:gpgkey, :parent => Puppet::IniProperty) do
      desc "The URL for the GPG key with which packages from this
        repository are signed.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      # Should really check that it's a valid URL
      newvalue(/.*/) { }
    end

    newproperty(:include, :parent => Puppet::IniProperty) do
      desc "A URL from which to include the config.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      # Should really check that it's a valid URL
      newvalue(/.*/) { }
    end

    newproperty(:exclude, :parent => Puppet::IniProperty) do
      desc "List of shell globs. Matching packages will never be
        considered in updates or installs for this repo.
        #{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(/.*/) { }
    end

    newproperty(:includepkgs, :parent => Puppet::IniProperty) do
      desc "List of shell globs. If this is set, only packages
        matching one of the globs will be considered for
        update or install.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(/.*/) { }
    end

    newproperty(:enablegroups, :parent => Puppet::IniProperty) do
      desc "Determines whether yum will allow the use of
        package groups for this  repository. Possible
        values are '0', and '1'.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{(0|1)}) { }
    end

    newproperty(:failovermethod, :parent => Puppet::IniProperty) do
      desc "Either 'roundrobin' or 'priority'.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{roundrobin|priority}) { }
    end

    newproperty(:keepalive, :parent => Puppet::IniProperty) do
      desc "Either '1' or '0'. This tells yum whether or not HTTP/1.1
        keepalive  should  be  used with this repository.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{(0|1)}) { }
    end

     newproperty(:http_caching, :parent => Puppet::IniProperty) do
       desc "Either 'packages' or 'all' or 'none'.\n#{ABSENT_DOC}" 
       newvalue(:absent) { self.should = :absent }
       newvalue(%r(packages|all|none)) { }
     end

    newproperty(:timeout, :parent => Puppet::IniProperty) do
      desc "Number of seconds to wait for a connection before timing
        out.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{[0-9]+}) { }
    end

    newproperty(:metadata_expire, :parent => Puppet::IniProperty) do
      desc "Number of seconds after which the metadata will expire.
        #{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{[0-9]+}) { }
    end

    newproperty(:protect, :parent => Puppet::IniProperty) do
      desc "Enable or disable protection for this repository. Requires
        that the protectbase plugin is installed and enabled.
        #{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{(0|1)}) { }
    end

    newproperty(:priority, :parent => Puppet::IniProperty) do
      desc "Priority of this repository from 1-99. Requires that
        the priorities plugin is installed and enabled.
        #{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{[1-9][0-9]?}) { }
    end

    newproperty(:cost, :parent => Puppet::IniProperty) do
      desc "Cost of this repository.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(%r{\d+}) { }
    end

    newproperty(:proxy, :parent => Puppet::IniProperty) do
      desc "URL to the proxy server for this repository.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      # Should really check that it's a valid URL
      newvalue(/.*/) { }
    end

    newproperty(:proxy_username, :parent => Puppet::IniProperty) do
      desc "Username for this proxy.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(/.*/) { }
    end

    newproperty(:proxy_password, :parent => Puppet::IniProperty) do
      desc "Password for this proxy.\n#{ABSENT_DOC}"
      newvalue(:absent) { self.should = :absent }
      newvalue(/.*/) { }
    end
  end
end
