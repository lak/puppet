#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/resource/type'

describe Puppet::Resource::Type do
  def ensure_in_catalog(type, scope, parameters = nil)
    Puppet::Parser::ResourceTypeHarness.ensure_in_catalog(type, scope, parameters)
  end

  it "should have a 'name' attribute" do
    Puppet::Resource::Type.new(:hostclass, "foo").name.should == "foo"
  end

  [:code, :doc, :line, :file, :resource_type_collection, :ruby_code].each do |attr|
    it "should have a '#{attr}' attribute" do
      type = Puppet::Resource::Type.new(:hostclass, "foo")
      type.send(attr.to_s + "=", "yay")
      type.send(attr).should == "yay"
    end
  end

  [:hostclass, :node, :definition].each do |type|
    it "should know when it is a #{type}" do
      Puppet::Resource::Type.new(type, "foo").send("#{type}?").should be_true
    end
  end

  it "should indirect 'resource_type'" do
    Puppet::Resource::Type.indirection.name.should == :resource_type
  end

  it "should default to 'parser' for its terminus class" do
    Puppet::Resource::Type.indirection.terminus_class.should == :parser
  end

  describe "when converting to json" do
    before do
      @type = Puppet::Resource::Type.new(:hostclass, "foo")
    end

    def double_convert
      Puppet::Resource::Type.from_pson(PSON.parse(@type.to_pson))
    end

    it "should include the name and type" do
      double_convert.name.should == @type.name
      double_convert.type.should == @type.type
    end

    it "should include any arguments" do
      @type.set_arguments("one" => nil, "two" => "foo")

      params = double_convert.parameters_with_defaults
      params.should be_include("one")
      params["one"].should be_nil
      params["two"].should == "foo"
    end

    it "should include parameters set individually" do
      @type.newparam(:yay) { defaultto "boo" }

      double_convert.parameters_with_defaults["yay"].should == "boo"
    end

    it "should always include the metaparams" do
      PSON.parse(@type.to_pson)["arguments"].should be_include("noop")
    end

    [:line, :doc, :file, :parent].each do |attr|
      it "should include #{attr} when set" do
        @type.send(attr.to_s + "=", "value")
        double_convert.send(attr).should == "value"
      end

      it "should not include #{attr} when not set" do
        @type.to_pson[attr.to_s].should be_nil
      end
    end

    it "should not include docs if they are empty" do
      @type.doc = ""
      @type.to_pson["doc"].should be_nil
    end
  end

  describe "when a node"  do
    it "should allow a regex as its name" do
      lambda { Puppet::Resource::Type.new(:node, /foo/) }.should_not raise_error
    end

    it "should allow a AST::HostName instance as its name" do
      regex = Puppet::Parser::AST::Regex.new(:value => /foo/)
      name = Puppet::Parser::AST::HostName.new(:value => regex)
      lambda { Puppet::Resource::Type.new(:node, name) }.should_not raise_error
    end

    it "should match against the regexp in the AST::HostName when a HostName instance is provided" do
      regex = Puppet::Parser::AST::Regex.new(:value => /\w/)
      name = Puppet::Parser::AST::HostName.new(:value => regex)
      node = Puppet::Resource::Type.new(:node, name)

      node.match("foo").should be_true
    end

    it "should return the value of the hostname if provided a string-form AST::HostName instance as the name" do
      name = Puppet::Parser::AST::HostName.new(:value => "foo")
      node = Puppet::Resource::Type.new(:node, name)

      node.name.should == "foo"
    end

    describe "and the name is a regex" do
      it "should have a method that indicates that this is the case" do
        Puppet::Resource::Type.new(:node, /w/).should be_name_is_regex
      end

      it "should set its namespace to ''" do
        Puppet::Resource::Type.new(:node, /w/).namespace.should == ""
      end

      it "should return the regex converted to a string when asked for its name" do
        Puppet::Resource::Type.new(:node, /ww/).name.should == "ww"
      end

      it "should downcase the regex when returning the name as a string" do
        Puppet::Resource::Type.new(:node, /W/).name.should == "w"
      end

      it "should remove non-alpha characters when returning the name as a string" do
        Puppet::Resource::Type.new(:node, /w*w/).name.should_not include("*")
      end

      it "should remove leading dots when returning the name as a string" do
        Puppet::Resource::Type.new(:node, /.ww/).name.should_not =~ /^\./
      end

      it "should have a method for matching its regex name against a provided name" do
        Puppet::Resource::Type.new(:node, /.ww/).should respond_to(:match)
      end

      it "should return true when its regex matches the provided name" do
        Puppet::Resource::Type.new(:node, /\w/).match("foo").should be_true
      end

      it "should return false when its regex does not match the provided name" do
        (!!Puppet::Resource::Type.new(:node, /\d/).match("foo")).should be_false
      end

      it "should return true when its name, as a string, is matched against an equal string" do
        Puppet::Resource::Type.new(:node, "foo").match("foo").should be_true
      end

      it "should return false when its name is matched against an unequal string" do
        Puppet::Resource::Type.new(:node, "foo").match("bar").should be_false
      end

      it "should match names insensitive to case" do
        Puppet::Resource::Type.new(:node, "fOo").match("foO").should be_true
      end
    end

    it "should return the name converted to a string when the name is not a regex" do
      pending "Need to define LoadedCode behaviour first"
      name = Puppet::Parser::AST::HostName.new(:value => "foo")
      Puppet::Resource::Type.new(:node, name).name.should == "foo"
    end

    it "should return the name converted to a string when the name is a regex" do
      pending "Need to define LoadedCode behaviour first"
      name = Puppet::Parser::AST::HostName.new(:value => /regex/)
      Puppet::Resource::Type.new(:node, name).name.should == /regex/.to_s
    end

    it "should mark any created scopes as a node scope" do
      pending "Need to define LoadedCode behaviour first"
      name = Puppet::Parser::AST::HostName.new(:value => /regex/)
      Puppet::Resource::Type.new(:node, name).name.should == /regex/.to_s
    end
  end

  describe "when initializing" do
    it "should require a resource super type" do
      Puppet::Resource::Type.new(:hostclass, "foo").type.should == :hostclass
    end

    it "should fail if provided an invalid resource super type" do
      lambda { Puppet::Resource::Type.new(:nope, "foo") }.should raise_error(ArgumentError)
    end

    it "should set its name to the downcased, stringified provided name" do
      Puppet::Resource::Type.new(:hostclass, "Foo::Bar".intern).name.should == "foo::bar"
    end

    it "should set its namespace to the downcased, stringified qualified name for classes" do
      Puppet::Resource::Type.new(:hostclass, "Foo::Bar::Baz".intern).namespace.should == "foo::bar::baz"
    end

    [:definition, :node].each do |type|
      it "should set its namespace to the downcased, stringified qualified portion of the name for #{type}s" do
        Puppet::Resource::Type.new(type, "Foo::Bar::Baz".intern).namespace.should == "foo::bar"
      end
    end

    %w{code line file doc}.each do |arg|
      it "should set #{arg} if provided" do
        type = Puppet::Resource::Type.new(:hostclass, "foo", arg.to_sym => "something")
        type.send(arg).should == "something"
      end
    end

    it "should set any provided arguments with the keys as symbols" do
      type = Puppet::Resource::Type.new(:hostclass, "foo", :arguments => {:foo => "bar", :baz => "biz"})
      type.should be_valid_parameter("foo")
      type.should be_valid_parameter("baz")
    end

    it "should set any provided arguments with they keys as strings" do
      type = Puppet::Resource::Type.new(:hostclass, "foo", :arguments => {"foo" => "bar", "baz" => "biz"})
      type.should be_valid_parameter(:foo)
      type.should be_valid_parameter(:baz)
    end

    it "should function if provided no arguments" do
      type = Puppet::Resource::Type.new(:hostclass, "foo")
      type.should_not be_valid_parameter(:foo)
    end
  end

  describe "when testing the validity of an attribute" do
    it "should return true if the parameter was provided at initialization" do
      type = Puppet::Resource::Type.new(:hostclass, "foo", :arguments => {"yay" => "boo"})
      type.should be_valid_parameter("yay")
    end

    it "should return true if the parameter was created separately" do
      type = Puppet::Resource::Type.new(:hostclass, "foo")
      type.newparam(:yay) {}
      type.should be_valid_parameter("yay")
    end

    it "should return true if it is a metaparam" do
      Puppet::Resource::Type.new(:hostclass, "foo").should be_valid_parameter("require")
    end

    it "should return true if the parameter is named 'name'" do
      Puppet::Resource::Type.new(:hostclass, "foo").should be_valid_parameter("name")
    end

    it "should return true if it is a property" do
      type = Puppet::Resource::Type.new(:hostclass, "foo")
      type.newproperty(:yay) {}
      type.should be_valid_parameter("yay")
    end

    it "should return false if it is not a metaparam and was not provided at initialization" do
      Puppet::Resource::Type.new(:hostclass, "foo").should_not be_valid_parameter("yayness")
    end
  end

  describe "when describing and managing parent classes" do
    before do
      @code = Puppet::Resource::TypeCollection.new("env")
      @parent = Puppet::Resource::Type.new(:hostclass, "bar")
      @code.add @parent

      @child = Puppet::Resource::Type.new(:hostclass, "foo", :parent => "bar")
      @code.add @child

      @env   = stub "environment", :known_resource_types => @code
      @scope = stub "scope", :environment => @env, :namespaces => [""]
    end

    it "should be able to define a parent" do
      Puppet::Resource::Type.new(:hostclass, "foo", :parent => "bar")
    end

    it "should use the code collection to find the parent resource type" do
      @child.parent_type(@scope).should equal(@parent)
    end

    it "should be able to find parent nodes" do
      parent = Puppet::Resource::Type.new(:node, "bar")
      @code.add parent
      child = Puppet::Resource::Type.new(:node, "foo", :parent => "bar")
      @code.add child

      child.parent_type(@scope).should equal(parent)
    end

    it "should cache a reference to the parent type" do
      @code.stubs(:hostclass).with("foo::bar").returns nil
      @code.expects(:hostclass).with("bar").once.returns @parent
      @child.parent_type(@scope)
      @child.parent_type
    end

    it "should correctly state when it is another type's child" do
      @child.parent_type(@scope)
      @child.should be_child_of(@parent)
    end

    it "should be considered the child of a parent's parent" do
      @grandchild = Puppet::Resource::Type.new(:hostclass, "baz", :parent => "foo")
      @code.add @grandchild

      @child.parent_type(@scope)
      @grandchild.parent_type(@scope)

      @grandchild.should be_child_of(@parent)
    end

    it "should correctly state when it is not another type's child" do
      @notchild = Puppet::Resource::Type.new(:hostclass, "baz")
      @code.add @notchild

      @notchild.should_not be_child_of(@parent)
    end
  end

  describe "when merging code from another instance" do
    def code(str)
      Puppet::Parser::AST::Leaf.new :value => str
    end

    it "should fail unless it is a class" do
      lambda { Puppet::Resource::Type.new(:node, "bar").merge("foo") }.should raise_error(Puppet::Error)
    end

    it "should fail unless the source instance is a class" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar")
      source = Puppet::Resource::Type.new(:node, "foo")
      lambda { dest.merge(source) }.should raise_error(Puppet::Error)
    end

    it "should fail if both classes have different parent classes" do
      code = Puppet::Resource::TypeCollection.new("env")
      {"a" => "b", "c" => "d"}.each do |parent, child|
        code.add Puppet::Resource::Type.new(:hostclass, parent)
        code.add Puppet::Resource::Type.new(:hostclass, child, :parent => parent)
      end
      lambda { code.hostclass("b").merge(code.hostclass("d")) }.should raise_error(Puppet::Error)
    end

    it "should fail if it's named 'main' and 'freeze_main' is enabled" do
      Puppet.settings[:freeze_main] = true
      code = Puppet::Resource::TypeCollection.new("env")
      code.add Puppet::Resource::Type.new(:hostclass, "")
      other = Puppet::Resource::Type.new(:hostclass, "")
      lambda { code.hostclass("").merge(other) }.should raise_error(Puppet::Error)
    end

    it "should copy the other class's parent if it has not parent" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar")

      parent = Puppet::Resource::Type.new(:hostclass, "parent")
      source = Puppet::Resource::Type.new(:hostclass, "foo", :parent => "parent")
      dest.merge(source)

      dest.parent.should == "parent"
    end

    it "should copy the other class's documentation as its docs if it has no docs" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar")
      source = Puppet::Resource::Type.new(:hostclass, "foo", :doc => "yayness")
      dest.merge(source)

      dest.doc.should == "yayness"
    end

    it "should append the other class's docs to its docs if it has any" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar", :doc => "fooness")
      source = Puppet::Resource::Type.new(:hostclass, "foo", :doc => "yayness")
      dest.merge(source)

      dest.doc.should == "foonessyayness"
    end

    it "should turn its code into an ASTArray if necessary" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar", :code => code("foo"))
      source = Puppet::Resource::Type.new(:hostclass, "foo", :code => code("bar"))

      dest.merge(source)

      dest.code.should be_instance_of(Puppet::Parser::AST::ASTArray)
    end

    it "should set the other class's code as its code if it has none" do
      dest = Puppet::Resource::Type.new(:hostclass, "bar")
      source = Puppet::Resource::Type.new(:hostclass, "foo", :code => code("bar"))

      dest.merge(source)

      dest.code.value.should == "bar"
    end

    it "should append the other class's code to its code if it has any" do
      dcode = Puppet::Parser::AST::ASTArray.new :children => [code("dest")]
      dest = Puppet::Resource::Type.new(:hostclass, "bar", :code => dcode)

      scode = Puppet::Parser::AST::ASTArray.new :children => [code("source")]
      source = Puppet::Resource::Type.new(:hostclass, "foo", :code => scode)

      dest.merge(source)

      dest.code.children.collect { |l| l.value }.should == %w{dest source}
    end
  end
end
