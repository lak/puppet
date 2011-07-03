#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/resource/type/metaparameters'

describe Puppet::Type::RelationshipMetaparam do
  it "should be a subclass of Puppet::Parameter" do
    Puppet::Type::RelationshipMetaparam.superclass.should equal(Puppet::Parameter)
  end

  it "should be able to produce a list of subclasses" do
    Puppet::Type::RelationshipMetaparam.should respond_to(:subclasses)
  end

  describe "when munging relationships" do
    before do
      @resource = Puppet::Type.type(:mount).new :name => "/foo"
      @metaparam = Puppet::Type.metaparamclass(:require).new :resource => @resource
    end

    it "should accept Puppet::Resource instances" do
      ref = Puppet::Resource.new(:file, "/foo")
      @metaparam.munge(ref)[0].should equal(ref)
    end

    it "should turn any string into a Puppet::Resource" do
      @metaparam.munge("File[/ref]")[0].should be_instance_of(Puppet::Resource)
    end
  end

  it "should be able to validate relationships" do
    Puppet::Type.metaparamclass(:require).new(:resource => mock("resource")).should respond_to(:validate_relationship)
  end

  it "should fail if any specified resource is not found in the catalog" do
    catalog = mock 'catalog'
    resource = stub 'resource', :catalog => catalog, :ref => "resource"

    param = Puppet::Type.metaparamclass(:require).new(:resource => resource, :value => %w{Foo[bar] Class[test]})

    catalog.expects(:resource).with("Foo[bar]").returns "something"
    catalog.expects(:resource).with("Class[Test]").returns nil

    param.expects(:fail).with { |string| string.include?("Class[Test]") }

    param.validate_relationship
  end
end

describe Puppet::Type.metaparamclass(:check) do
  it "should warn and create an instance of ':audit'" do
    file = Puppet::Type.type(:file).new :path => "/foo"
    file.expects(:warning)
    file[:check] = :mode
    file[:audit].should == [:mode]
  end
end

describe Puppet::Type.metaparamclass(:audit) do
  before do
    @resource = Puppet::Type.type(:file).new :path => "/foo"
  end

  it "should default to being nil" do
    @resource[:audit].should be_nil
  end

  it "should specify all possible properties when asked to audit all properties" do
    @resource[:audit] = :all

    list = @resource.class.properties.collect { |p| p.name }
    @resource[:audit].should == list
  end

  it "should accept the string 'all' to specify auditing all possible properties" do
    @resource[:audit] = 'all'

    list = @resource.class.properties.collect { |p| p.name }
    @resource[:audit].should == list
  end

  it "should fail if asked to audit an invalid property" do
    lambda { @resource[:audit] = :foobar }.should raise_error(Puppet::Error)
  end

  it "should create an attribute instance for each auditable property" do
    @resource[:audit] = :mode
    @resource.parameter(:mode).should_not be_nil
  end

  it "should accept properties specified as a string" do
    @resource[:audit] = "mode"
    @resource.parameter(:mode).should_not be_nil
  end

  it "should not create attribute instances for parameters, only properties" do
    @resource[:audit] = :noop
    @resource.parameter(:noop).should be_nil
  end

  describe "when generating the uniqueness key" do
    it "should include all of the key_attributes in alphabetical order by attribute name" do
      Puppet::Type.type(:file).stubs(:key_attributes).returns [:path, :mode, :owner]
      Puppet::Type.type(:file).stubs(:title_patterns).returns(
        [ [ /(.*)/, [ [:path, lambda{|x| x} ] ] ] ]
      )
      res = Puppet::Type.type(:file).new( :title => '/my/file', :path => '/my/file', :owner => 'root', :content => 'hello' )
      res.uniqueness_key.should == [ nil, 'root', '/my/file']
    end
  end
end
