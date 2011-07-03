#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/parser/resource_type_harness'

describe Puppet::Parser::ResourceTypeHarness do
  def harness
    Puppet::Parser::ResourceTypeHarness
  end

  describe "when creating a resource" do
    before do
      @node = Puppet::Node.new("foo", :environment => 'env')
      @compiler = Puppet::Parser::Compiler.new(@node)
      @scope = Puppet::Parser::Scope.new(:compiler => @compiler)

      @top = Puppet::Resource::Type.new :hostclass, "top"
      @middle = Puppet::Resource::Type.new :hostclass, "middle", :parent => "top"

      @code = Puppet::Resource::TypeCollection.new("env")
      @code.add @top
      @code.add @middle

      @node.environment.stubs(:known_resource_types).returns(@code)
    end

    it "should create a resource instance" do
      harness.ensure_in_catalog(@top, @scope).should be_instance_of(Puppet::Parser::Resource)
    end

    it "should set its resource type to 'class' when it is a hostclass" do
      harness.ensure_in_catalog(Puppet::Resource::Type.new(:hostclass, "top"), @scope).type.should == "Class"
    end

    it "should set its resource type to 'node' when it is a node" do
      harness.ensure_in_catalog(Puppet::Resource::Type.new(:node, "top"), @scope).type.should == "Node"
    end

    it "should fail when it is a definition" do
      lambda { harness.ensure_in_catalog(Puppet::Resource::Type.new(:definition, "top"), @scope) }.should raise_error(ArgumentError)
    end

    it "should add the created resource to the scope's catalog" do
      harness.ensure_in_catalog(@top, @scope)

      @compiler.catalog.resource(:class, "top").should be_instance_of(Puppet::Parser::Resource)
    end

    it "should add specified parameters to the resource" do
      harness.ensure_in_catalog(@top, @scope, {'one'=>'1', 'two'=>'2'})
      @compiler.catalog.resource(:class, "top")['one'].should == '1'
      @compiler.catalog.resource(:class, "top")['two'].should == '2'
    end

    it "should not require params for a param class" do
      harness.ensure_in_catalog(@top, @scope, {})
      @compiler.catalog.resource(:class, "top").should be_instance_of(Puppet::Parser::Resource)
    end

    it "should evaluate the parent class if one exists" do
      harness.ensure_in_catalog(@middle, @scope)

      @compiler.catalog.resource(:class, "top").should be_instance_of(Puppet::Parser::Resource)
    end

    it "should evaluate the parent class if one exists" do
      harness.ensure_in_catalog(@middle, @scope)

      @compiler.catalog.resource(:class, "top").should be_instance_of(Puppet::Parser::Resource)
    end

    it "should fail if you try to create duplicate class resources" do
      othertop = Puppet::Parser::Resource.new(:class, 'top',:source => @source, :scope => @scope )
      # add the same class resource to the catalog
      @compiler.catalog.add_resource(othertop)
      lambda { harness.ensure_in_catalog(@top, @scope, {}) }.should raise_error(Puppet::Resource::Catalog::DuplicateResourceError)
    end

    it "should fail to evaluate if a parent class is defined but cannot be found" do
      othertop = Puppet::Resource::Type.new :hostclass, "something", :parent => "yay"
      @code.add othertop
      lambda { harness.ensure_in_catalog(othertop, @scope) }.should raise_error(Puppet::ParseError)
    end

    it "should not create a new resource if one already exists" do
      @compiler.catalog.expects(:resource).with(:class, "top").returns("something")
      @compiler.catalog.expects(:add_resource).never
      harness.ensure_in_catalog(@top, @scope)
    end

    it "should return the existing resource when not creating a new one" do
      @compiler.catalog.expects(:resource).with(:class, "top").returns("something")
      @compiler.catalog.expects(:add_resource).never
      harness.ensure_in_catalog(@top, @scope).should == "something"
    end

    it "should not create a new parent resource if one already exists and it has a parent class" do
      harness.ensure_in_catalog(@top, @scope)

      top_resource = @compiler.catalog.resource(:class, "top")

      harness.ensure_in_catalog(@middle, @scope)

      @compiler.catalog.resource(:class, "top").should equal(top_resource)
    end

    # #795 - tag before evaluation.
    it "should tag the catalog with the resource tags when it is evaluated" do
      harness.ensure_in_catalog(@middle, @scope)

      @compiler.catalog.should be_tagged("middle")
    end

    it "should tag the catalog with the parent class tags when it is evaluated" do
      harness.ensure_in_catalog(@middle, @scope)

      @compiler.catalog.should be_tagged("top")
    end
  end

  describe "when evaluating code" do
    before do
      @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
      @scope = Puppet::Parser::Scope.new :compiler => @compiler
      @resource = Puppet::Parser::Resource.new(:foo, "yay", :scope => @scope)

      # This is so the internal resource lookup works, yo.
      @compiler.catalog.add_resource @resource

      @known_resource_types = stub 'known_resource_types'
      @resource.stubs(:known_resource_types).returns @known_resource_types
      @type = Puppet::Resource::Type.new(:hostclass, "foo")
    end

    it "should add hostclass names to the classes list" do
      harness.evaluate_code(@type, @resource)
      @compiler.catalog.classes.should be_include("foo")
    end

    it "should add node names to the classes list" do
      @type = Puppet::Resource::Type.new(:node, "foo")
      harness.evaluate_code(@type, @resource)
      @compiler.catalog.classes.should be_include("foo")
    end

    it "should not add defined resource names to the classes list" do
      @type = Puppet::Resource::Type.new(:definition, "foo")
      harness.evaluate_code(@type, @resource)
      @compiler.catalog.classes.should_not be_include("foo")
    end

    it "should set all of its parameters in a subscope" do
      subscope = @scope.newscope
      @scope.expects(:newscope).with(:source => @type, :dynamic => true, :namespace => 'foo', :resource => @resource).returns subscope
      harness.expects(:set_resource_parameters).with(@type, @resource, subscope)

      harness.evaluate_code(@type, @resource)
    end

    it "should not create a subscope for the :main class" do
      @resource.stubs(:title).returns(:main)
      @type.expects(:subscope).never
      harness.expects(:set_resource_parameters).with(@type, @resource, @scope)

      harness.evaluate_code(@type, @resource)
    end

    it "should store the class scope" do
      harness.evaluate_code(@type, @resource)
      @scope.class_scope(@type).should be_instance_of(@scope.class)
    end

    it "should still create a scope but not store it if the type is a definition" do
      @type = Puppet::Resource::Type.new(:definition, "foo")
      harness.evaluate_code(@type, @resource)
      @scope.class_scope(@type).should be_nil
    end

    it "should evaluate the AST code if any is provided" do
      code = stub 'code'
      @type.stubs(:code).returns code
      subscope = stub_everything("subscope", :compiler => @compiler)
      @scope.stubs(:newscope).returns subscope
      code.expects(:safeevaluate).with subscope

      harness.evaluate_code(@type, @resource)
    end

    describe "and ruby code is provided" do
      it "should create a DSL Resource API and evaluate it" do
        @type.stubs(:ruby_code).returns(proc { "foo" })
        @api = stub 'api'
        Puppet::DSL::ResourceAPI.expects(:new).with { |res, scope, type, code| code == @type.ruby_code }.returns @api
        @api.expects(:evaluate)

        harness.evaluate_code(@type, @resource)
      end
    end

    it "should noop if there is no code" do
      @type.expects(:code).returns nil

      harness.evaluate_code(@type, @resource)
    end

    describe "and it has a parent class" do
      before do
        @parent_type = Puppet::Resource::Type.new(:hostclass, "parent")
        @type.parent = "parent"
        @parent_resource = Puppet::Parser::Resource.new(:class, "parent", :scope => @scope)

        @compiler.add_resource @scope, @parent_resource

        @type.resource_type_collection = @scope.known_resource_types
        @type.resource_type_collection.add @parent_type
      end

      it "should evaluate the parent's resource" do
        @type.parent_type(@scope)

        harness.evaluate_code(@type, @resource)

        @scope.class_scope(@parent_type).should_not be_nil
      end

      it "should not evaluate the parent's resource if it has already been evaluated" do
        @parent_resource.evaluate

        @type.parent_type(@scope)

        @parent_resource.expects(:evaluate).never

        harness.evaluate_code(@type, @resource)
      end

      it "should use the parent's scope as its base scope" do
        @type.parent_type(@scope)

        harness.evaluate_code(@type, @resource)

        @scope.class_scope(@type).parent.object_id.should == @scope.class_scope(@parent_type).object_id
      end
    end

    describe "and it has a parent node" do
      before do
        @type = Puppet::Resource::Type.new(:node, "foo")
        @parent_type = Puppet::Resource::Type.new(:node, "parent")
        @type.parent = "parent"
        @parent_resource = Puppet::Parser::Resource.new(:node, "parent", :scope => @scope)

        @compiler.add_resource @scope, @parent_resource

        @type.resource_type_collection = @scope.known_resource_types
        @type.resource_type_collection.add(@parent_type)
      end

      it "should evaluate the parent's resource" do
        @type.parent_type(@scope)

        harness.evaluate_code(@type, @resource)

        @scope.class_scope(@parent_type).should_not be_nil
      end

      it "should not evaluate the parent's resource if it has already been evaluated" do
        @parent_resource.evaluate

        @type.parent_type(@scope)

        @parent_resource.expects(:evaluate).never

        harness.evaluate_code(@type, @resource)
      end

      it "should use the parent's scope as its base scope" do
        @type.parent_type(@scope)

        harness.evaluate_code(@type, @resource)

        @scope.class_scope(@type).parent.object_id.should == @scope.class_scope(@parent_type).object_id
      end
    end
  end

  describe "when setting its parameters in the scope" do
    before do
      @scope = Puppet::Parser::Scope.new(:compiler => stub("compiler", :environment => Puppet::Node::Environment.new), :source => stub("source"))
      @resource = Puppet::Parser::Resource.new(:foo, "bar", :scope => @scope)
      @type = Puppet::Resource::Type.new(:hostclass, "foo")
    end

    ['module_name', 'name', 'title'].each do |variable|
      it "should allow #{variable} to be evaluated as param default" do
        @type.instance_eval { @module_name = "bar" }
        var = Puppet::Parser::AST::Variable.new({'value' => variable})
        @type.set_arguments :foo => var
        harness.set_resource_parameters(@type, @resource, @scope)
        @scope.lookupvar('foo').should == 'bar'
      end
    end

    # this test is to clarify a crazy edge case
    # if you specify these special names as params, the resource
    # will override the special variables
    it "resource should override defaults" do
      @type.set_arguments :name => nil
      @resource[:name] = 'foobar'
      var = Puppet::Parser::AST::Variable.new({'value' => 'name'})
      @type.set_arguments :foo => var
      harness.set_resource_parameters(@type, @resource, @scope)
      @scope.lookupvar('foo').should == 'foobar'
    end

    it "should set each of the resource's parameters as variables in the scope" do
      @type.set_arguments :foo => nil, :boo => nil
      @resource[:foo] = "bar"
      @resource[:boo] = "baz"

      harness.set_resource_parameters(@type, @resource, @scope)

      @scope.lookupvar("foo").should == "bar"
      @scope.lookupvar("boo").should == "baz"
    end

    it "should set the variables as strings" do
      @type.set_arguments :foo => nil
      @resource[:foo] = "bar"

      harness.set_resource_parameters(@type, @resource, @scope)

      @scope.lookupvar("foo").should == "bar"
    end

    it "should fail if any of the resource's parameters are not valid attributes" do
      @type.set_arguments :foo => nil
      @resource[:boo] = "baz"

      lambda { harness.set_resource_parameters(@type, @resource, @scope) }.should raise_error(Puppet::ParseError)
    end

    it "should evaluate and set its default values as variables for parameters not provided by the resource" do
      @type.set_arguments :foo => stub("value", :safeevaluate => "something")
      harness.set_resource_parameters(@type, @resource, @scope)
      @scope.lookupvar("foo").should == "something"
    end

    it "should set all default values as parameters in the resource" do
      @type.set_arguments :foo => stub("value", :safeevaluate => "something")

      harness.set_resource_parameters(@type, @resource, @scope)

      @resource[:foo].should == "something"
    end

    it "should fail if the resource does not provide a value for a required argument" do
      @type.set_arguments :foo => nil
      @resource.expects(:to_hash).returns({})

      lambda { harness.set_resource_parameters(@type, @resource, @scope) }.should raise_error(Puppet::ParseError)
    end

    it "should set the resource's title as a variable if not otherwise provided" do
      harness.set_resource_parameters(@type, @resource, @scope)

      @scope.lookupvar("title").should == "bar"
    end

    it "should set the resource's name as a variable if not otherwise provided" do
      harness.set_resource_parameters(@type, @resource, @scope)

      @scope.lookupvar("name").should == "bar"
    end

    it "should set its module name in the scope if available" do
      @type.instance_eval { @module_name = "mymod" }

      harness.set_resource_parameters(@type, @resource, @scope)

      @scope.lookupvar("module_name").should == "mymod"
    end

    it "should set its caller module name in the scope if available" do
      @scope.expects(:parent_module_name).returns "mycaller"

      harness.set_resource_parameters(@type, @resource, @scope)

      @scope.lookupvar("caller_module_name").should == "mycaller"
    end
  end
end
