require 'puppet/util'

class Puppet::Util::InteractiveShell
  class ShellContext
    attr_accessor :cwd
    def initialize
      @cwd = []
    end

    def pwd
      "/" + @cwd.join("/")
    end
  end

  attr_reader :context, :face

  def initialize
    @context = ShellContext.new
    @face = Puppet::Face[:shell, "0.0.1"] or raise("Could not find 'shell' face")
  end

  def get_command
    begin
      $stdin.readline
    rescue EOFError
      # Hackish, but sufficient.
      return "quit"
    end
  end

  def interact
    while true do
      begin
        prompt
        command = get_command
        execute_shell_action(command)
      rescue => detail
        puts detail.backtrace
        $stderr.puts detail
      end
    end
  end

  def prompt
    print "#{context.pwd} > "
  end

  def execute_shell_action(line)
    rest_of_line = line.split(/\s+/)
    action_name = rest_of_line.shift
    unless action = Puppet::Face.find_action(:shell, action_name)
      raise "Could not find #{action_name}"
    end

    # Add our context in an options hash that the actions can
    # handle.
    args = rest_of_line
    args << {:context => context}

    result = face.send(action.name, *args)
    puts action.render(:console, result) unless result.nil?
    status = true
  end
end
