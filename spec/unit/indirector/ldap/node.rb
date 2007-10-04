#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/ldap/node'

module LdapNodeSearching
    def setup
        @searcher = Puppet::Indirector::Ldap::Node.new
        @entries = {}
        entries = @entries
        
        @connection = mock 'connection'
        @entry = mock 'entry'
        @connection.stubs(:search).yields(@entry)
        @searcher.stubs(:connection).returns(@connection)
        @searcher.stubs(:class_attributes).returns([])
        @searcher.stubs(:parent_attribute).returns(nil)
        @searcher.stubs(:search_base).returns(:yay)
        @searcher.stubs(:search_filter).returns(:filter)

        @node = mock 'node'
        @node.stubs(:fact_merge)
        @name = "mynode"
        Puppet::Node.stubs(:new).with(@name).returns(@node)
    end
end

describe Puppet::Indirector::Ldap::Node, " when searching for nodes" do
    include LdapNodeSearching

    it "should return nil if no results are found in ldap" do
        @connection.stubs(:search)
        @searcher.find("mynode").should be_nil
    end

    it "should return a node object if results are found in ldap" do
        @entry.stubs(:to_hash).returns({})
        @searcher.find("mynode").should equal(@node)
    end

    it "should deduplicate class values" do
        @entry.stubs(:to_hash).returns({})
        @searcher.stubs(:class_attributes).returns(%w{one two})
        @entry.stubs(:vals).with("one").returns(%w{a b})
        @entry.stubs(:vals).with("two").returns(%w{b c})
        @node.expects(:classes=).with(%w{a b c})
        @searcher.find("mynode")
    end

    it "should add any values stored in the class_attributes attributes to the node classes" do
        @entry.stubs(:to_hash).returns({})
        @searcher.stubs(:class_attributes).returns(%w{one two})
        @entry.stubs(:vals).with("one").returns(%w{a b})
        @entry.stubs(:vals).with("two").returns(%w{c d})
        @node.expects(:classes=).with(%w{a b c d})
        @searcher.find("mynode")
    end

    it "should add all entry attributes as node parameters" do
        @entry.stubs(:to_hash).returns("one" => ["two"], "three" => ["four"])
        @node.expects(:parameters=).with("one" => "two", "three" => "four")
        @searcher.find("mynode")
    end

    it "should retain false parameter values" do
        @entry.stubs(:to_hash).returns("one" => [false])
        @node.expects(:parameters=).with("one" => false)
        @searcher.find("mynode")
    end

    it "should turn single-value parameter value arrays into single non-arrays" do
        @entry.stubs(:to_hash).returns("one" => ["a"])
        @node.expects(:parameters=).with("one" => "a")
        @searcher.find("mynode")
    end

    it "should keep multi-valued parametes as arrays" do
        @entry.stubs(:to_hash).returns("one" => ["a", "b"])
        @node.expects(:parameters=).with("one" => ["a", "b"])
        @searcher.find("mynode")
    end
end

describe Puppet::Indirector::Ldap::Node, " when a parent node exists" do
    include LdapNodeSearching

    before do
        @parent = mock 'parent'
        @parent_parent = mock 'parent_parent'

        @searcher.meta_def(:search_filter) do |name|
            return name
        end
        @connection.stubs(:search).with { |*args| args[2] == @name              }.yields(@entry)
        @connection.stubs(:search).with { |*args| args[2] == 'parent'           }.yields(@parent)
        @connection.stubs(:search).with { |*args| args[2] == 'parent_parent'    }.yields(@parent_parent)

        @searcher.stubs(:parent_attribute).returns(:parent)
    end

    it "should add any parent classes to the node's classes" do
        @entry.stubs(:to_hash).returns({})
        @entry.stubs(:vals).with(:parent).returns(%w{parent})
        @entry.stubs(:vals).with("classes").returns(%w{a b})

        @parent.stubs(:to_hash).returns({})
        @parent.stubs(:vals).with("classes").returns(%w{c d})
        @parent.stubs(:vals).with(:parent).returns(nil)

        @searcher.stubs(:class_attributes).returns(%w{classes})
        @node.expects(:classes=).with(%w{a b c d})
        @searcher.find("mynode")
    end

    it "should add any parent parameters to the node's parameters" do
        @entry.stubs(:to_hash).returns("one" => "two")
        @entry.stubs(:vals).with(:parent).returns(%w{parent})

        @parent.stubs(:to_hash).returns("three" => "four")
        @parent.stubs(:vals).with(:parent).returns(nil)

        @node.expects(:parameters=).with("one" => "two", "three" => "four")
        @searcher.find("mynode")
    end

    it "should prefer node parameters over parent parameters" do
        @entry.stubs(:to_hash).returns("one" => "two")
        @entry.stubs(:vals).with(:parent).returns(%w{parent})

        @parent.stubs(:to_hash).returns("one" => "three")
        @parent.stubs(:vals).with(:parent).returns(nil)

        @node.expects(:parameters=).with("one" => "two")
        @searcher.find("mynode")
    end

    it "should recursively look up parent information" do
        @entry.stubs(:to_hash).returns("one" => "two")
        @entry.stubs(:vals).with(:parent).returns(%w{parent})

        @parent.stubs(:to_hash).returns("three" => "four")
        @parent.stubs(:vals).with(:parent).returns(['parent_parent'])

        @parent_parent.stubs(:to_hash).returns("five" => "six")
        @parent_parent.stubs(:vals).with(:parent).returns(nil)
        @parent_parent.stubs(:vals).with(:parent).returns(nil)

        @node.expects(:parameters=).with("one" => "two", "three" => "four", "five" => "six")
        @searcher.find("mynode")
    end

    it "should not allow loops in parent declarations" do
        @entry.stubs(:to_hash).returns("one" => "two")
        @entry.stubs(:vals).with(:parent).returns(%w{parent})

        @parent.stubs(:to_hash).returns("three" => "four")
        @parent.stubs(:vals).with(:parent).returns([@name])
        proc { @searcher.find("mynode") }.should raise_error(ArgumentError)
    end
end

describe Puppet::Indirector::Ldap::Node, " when developing the search query" do
    before do
        @searcher = Puppet::Indirector::Ldap::Node.new
    end

    it "should return the value of the :ldapclassattrs split on commas as the class attributes" do
        Puppet.stubs(:[]).with(:ldapclassattrs).returns("one,two")
        @searcher.class_attributes.should == %w{one two}
    end

    it "should return nil as the parent attribute if the :ldapparentattr is set to an empty string" do
        Puppet.stubs(:[]).with(:ldapparentattr).returns("")
        @searcher.parent_attribute.should be_nil
    end

    it "should return the value of the :ldapparentattr as the parent attribute" do
        Puppet.stubs(:[]).with(:ldapparentattr).returns("pere")
        @searcher.parent_attribute.should == "pere"
    end

    it "should use the value of the :ldapstring as the search filter" do
        Puppet.stubs(:[]).with(:ldapstring).returns("mystring")
        @searcher.search_filter("testing").should == "mystring"
    end

    it "should replace '%s' with the node name in the search filter if it is present" do
        Puppet.stubs(:[]).with(:ldapstring).returns("my%sstring")
        @searcher.search_filter("testing").should == "mytestingstring"
    end

    it "should not modify the global :ldapstring when replacing '%s' in the search filter" do
        filter = mock 'filter'
        filter.expects(:include?).with("%s").returns(true)
        filter.expects(:gsub).with("%s", "testing").returns("mynewstring")
        Puppet.stubs(:[]).with(:ldapstring).returns(filter)
        @searcher.search_filter("testing").should == "mynewstring"
    end
end

describe Puppet::Indirector::Ldap::Node, " when deciding attributes to search for" do
    before do
        @searcher = Puppet::Indirector::Ldap::Node.new
    end

    it "should use 'nil' if the :ldapattrs setting is 'all'" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("all")
        @searcher.search_attributes.should be_nil
    end

    it "should split the value of :ldapattrs on commas and use the result as the attribute list" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
        @searcher.stubs(:class_attributes).returns([])
        @searcher.stubs(:parent_attribute).returns(nil)
        @searcher.search_attributes.should == %w{one two}
    end

    it "should add the class attributes to the search attributes if not returning all attributes" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
        @searcher.stubs(:class_attributes).returns(%w{three four})
        @searcher.stubs(:parent_attribute).returns(nil)
        # Sort them so i don't have to care about return order
        @searcher.search_attributes.sort.should == %w{one two three four}.sort
    end

    it "should add the parent attribute to the search attributes if not returning all attributes" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
        @searcher.stubs(:class_attributes).returns([])
        @searcher.stubs(:parent_attribute).returns("parent")
        @searcher.search_attributes.sort.should == %w{one two parent}.sort
    end

    it "should not add nil parent attributes to the search attributes" do
        Puppet.stubs(:[]).with(:ldapattrs).returns("one,two")
        @searcher.stubs(:class_attributes).returns([])
        @searcher.stubs(:parent_attribute).returns(nil)
        @searcher.search_attributes.should == %w{one two}
    end
end
