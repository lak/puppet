# Rakefile for Puppet -*- ruby -*-

# We need access to the Puppet.version method
$LOAD_PATH.unshift(File.expand_path("lib"))
require 'puppet/version'

$LOAD_PATH << File.join(File.dirname(__FILE__), 'tasks')

begin
  require 'rubygems'
  require 'rubygems/package_task'
  require 'rspec'
  require 'rspec/core/rake_task'
rescue LoadError
  # Users of older versions of Rake (0.8.7 for example) will not necessarily
  # have rubygems installed, or the newer rubygems package_task for that
  # matter.
  require 'rake/packagetask'
  require 'rake/gempackagetask'
end

require 'rake'

Dir['tasks/**/*.rake'].each { |t| load t }
Dir['ext/packaging/tasks/**/*'].sort.each { |t| load t }

build_defs_file = 'ext/build_defaults.yaml'
if File.exist?(build_defs_file)
  begin
    require 'yaml'
    @build_defaults ||= YAML.load_file(build_defs_file)
  rescue Exception => e
    STDERR.puts "Unable to load yaml from #{build_defs_file}:"
    STDERR.puts e
  end
  @packaging_url  = @build_defaults['packaging_url']
  @packaging_repo = @build_defaults['packaging_repo']
  raise "Could not find packaging url in #{build_defs_file}" if @packaging_url.nil?
  raise "Could not find packaging repo in #{build_defs_file}" if @packaging_repo.nil?

  namespace :package do
    desc "Bootstrap packaging automation, e.g. clone into packaging repo"
    task :bootstrap do
      if File.exist?("ext/#{@packaging_repo}")
        puts "It looks like you already have ext/#{@packaging_repo}. If you don't like it, blow it away with package:implode."
      else
        cd 'ext' do
          %x{git clone #{@packaging_url}}
        end
      end
    end
    desc "Remove all cloned packaging automation"
    task :implode do
      rm_rf "ext/#{@packaging_repo}"
    end
  end
end

task :default do
    sh %{rake -T}
end

if defined?(RSpec::Core::RakeTask)
  RSpec::Core::RakeTask.new do |t|
      t.pattern ='spec/**/*_spec.rb'
      t.fail_on_error = true
  end
end

desc "Rebuild the parser file from the grammer"
task :parser => "lib/puppet/parser/parser.rb"

file "lib/puppet/parser/grammer.ra"

file "lib/puppet/parser/parser.rb" => "lib/puppet/parser/grammer.ra" do
  sh "racc -olib/puppet/parser/parser.rb lib/puppet/parser/grammar.ra"
end

desc "Rebuild the parser file from the grammer and include a debug file"
file "lib/puppet/parser/grammar.output" => "lib/puppet/parser/grammer.ra" do
  sh "racc -v -olib/puppet/parser/parser.rb lib/puppet/parser/grammar.ra"
end
