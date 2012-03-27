require 'puppet/resource'

# The resources that someone has said, on this system, are worth auditing.
class Puppet::Resource::Audited
  # We only need one of these.  We'll add locking etc. later.
  def self.new(name = nil)
    return @instance if @instance

    obj = self.allocate
    obj.send :initialize
    @instance = obj
  end

  def audited
    @audited_resources.keys.sort
  end

  def audited?(resource)
    @audited_resources.has_key?(resource.ref)
  end

  def audit(resource)
    Puppet.info "Auditing #{resource} during auditing. Use 'puppet resource release' to release."
    @audited_resources[resource.to_s] = true
  end

  def initialize
    @audited_resources = {}
  end

  def load
    if File.exist?(Puppet[:audited_resources])
      Puppet.debug "Loading audited resources"
      File.readlines(Puppet[:audited_resources]).collect { |l| l.chomp }.each { |ref| @audited_resources[ref] = true }
    end
  end

  def unaudit(resource)
    @audited_resources.delete(resource.to_s)
  end

  def write
    return if @audited_resources.empty? and ! File.exist?(Puppet[:audited_resources])
    Puppet.debug "Writing audited resources"
    File.open(Puppet[:audited_resources], "w") do |f|
      @audited_resources.each { |ref, t| f.puts ref }
    end
  end
end
