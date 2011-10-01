require 'spec_helper'

describe "RTM" do
  let(:lib) { RTM_CLI.new }
  let(:ykk_double) { double('ykk').as_null_object }

  before do
    YAML.stub(:load_file).and_raise(Errno::ENOENT)
  end

  it "loads the configuration dotfile" do
    YAML.should_receive(:load_file)
    lib
  end

  it "lists incomplete tasks" do
    pending
    #lib.list.should == ['lists incomplete tasks']
  end

  describe "authentication setup" do
    let(:auth_double) { double('auth') }

    before do
      RTM::RTM.stub_chain(:new, :auth) { auth_double }
      auth_double.stub(:url) { 'http://testurl' }
      auth_double.stub(:frob) { 'testfrob' }
    end

    it "directs the user to setup auth" do
      lib.auth_start.should == 'http://testurl'
    end

    it "stores the frob in configuration" do
      io_double = double('io')
      File.should_receive(:open).and_yield(io_double)
      YAML.should_receive(:dump).with({"frob"=>"testfrob"}, io_double)
      lib.auth_start
    end
  end

  describe "authentication completion" do
    it "loads the frob from the dotfile" do
      pending
    end
  end
end
