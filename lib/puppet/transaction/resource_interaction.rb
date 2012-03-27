require 'puppet/transaction'

class Puppet::Transaction::ResourceInteraction
  attr_accessor :changed, :resource, :current_values, :desired_values

  def continue?
    @continue
  end

  def go
    check_for_change
    return unless changed > 0
    answer = ask()
  end

  def initialize(resource, current_values, desired_values)
    @resource, @current_values, @desired_values = resource, current_values, desired_values
    @changed = 0
    @continue = false
  end

  private

  def ask
    while true do
      puts "What should I do? ([Change]/Hold/Fail/Noop)"
      answer = $stdin.readline.chomp
      answer = "c" if answer == ""
      answer = answer.downcase[0..0].intern
      case answer
      when :c: change; return
      when :h: hold; return
      when :f: fail; return
      when :n: noop; return
      else
        $stderr.puts "Invalid answer"
      end
    end
  end

  def change
    @continue = true
  end

  def check_for_change
    # XXX This is pretty hideous, because it just duplicates the logic in resource_harness.
    ensure_param = resource.parameter(:ensure)
    if desired_values[:ensure] && !ensure_param.safe_insync?(current_values[:ensure])
      @changed += 1
      puts "#{resource}.ensure: #{current_values[:ensure]} should be #{desired_values[:ensure]}"
    elsif current_values[:ensure] != :absent
      work_order = resource.properties # Note: only the resource knows what order to apply changes in
      work_order.each do |param|
        if desired_values[param.name] && !param.safe_insync?(current_values[param.name])
          @changed += 1
          puts "#{resource}.#{param}: #{current_values[param]} should be #{desired_values[param]}"
        end
      end
    end
    return changed
  end

  def fail
    resource.fail "Not changing during interactive use"
  end

  def hold
    resource.warning "Hold not yet implemented; setting to noop"
    noop
  end

  def noop
    resource.info "Interactively marking as noop"
    resource[:noop] = true
    @continue = true
  end
end
