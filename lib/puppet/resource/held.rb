require 'puppet/resource'

class Puppet::Resource::Held
  # We only need one of these.  We'll add locking etc. later.
  def self.new(name = nil)
    return @instance if @instance

    obj = self.allocate
    obj.send :initialize
    @instance = obj
  end

  def held
    @held_resources.keys.sort
  end

  def held?(resource)
    @held_resources.has_key?(resource.ref)
  end

  def hold(resource)
    Puppet.info "Holding #{resource} indefinitely. Use 'puppet resource release' to release."
    @held_resources[resource.to_s] = true
  end

  def initialize
    @held_resources = {}
  end

  def load
    if File.exist?(Puppet[:held_resources])
      Puppet.debug "Loading held resources"
      File.readlines(Puppet[:held_resources]).collect { |l| l.chomp }.each { |ref| @held_resources[ref] = true }
    end
  end

  def release(resource)
    @held_resources.delete(resource.to_s)
  end

  def write
    return if @held_resources.empty?
    Puppet.debug "Writing held resources"
    File.open(Puppet[:held_resources], "w") do |f|
      @held_resources.each { |ref, t| f.puts ref }
    end
  end
end
