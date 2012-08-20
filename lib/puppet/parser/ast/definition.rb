require 'puppet/parser/ast/top_level_construct'

class Puppet::Parser::AST::Definition < Puppet::Parser::AST::TopLevelConstruct
  attr_accessor :context, :capability

  def set_capability(hash)
    @capability = hash
  end

  def initialize(name, context = {}, &ruby_code)
    @name = name
    @context = context
    @ruby_code = ruby_code
  end

  def instantiate(modname)
    new_definition = Puppet::Resource::Type.new(:definition, @name, @context.merge(:module_name => modname))
    new_definition.ruby_code = @ruby_code if @ruby_code
    new_definition.set_capability(capability) if capability
    [new_definition]
  end
end
