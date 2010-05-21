#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/file_bucket_file/git'

describe Puppet::FileBucketFile::Git do
  include PuppetSpec::Files

  it "should be a subclass of the Code terminus class" do
    Puppet::FileBucketFile::File.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should have documentation" do
    Puppet::FileBucketFile::File.doc.should be_instance_of(String)
  end
end
