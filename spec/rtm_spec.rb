require 'spec_helper'

describe "RTM" do
  let(:lib) { RTM_CLI.new }
  let(:ykk_double) { double('ykk').as_null_object }

  before do
    YAML.stub(:load_file).and_raise(Errno::ENOENT)
  end

  it "loads the configuration dotfile" do
    ENV['HOME'] = 'testhome'
    YAML.should_receive(:load_file).with('testhome/.rtm')
    lib
  end

  it "lists incomplete tasks" do
    pending
    #lib.list.should == ['lists incomplete tasks']
  end

  describe "authentication" do
    let(:auth_double) { double('auth') }

    before do
      RTM::RTM.stub_chain(:new, :auth) { auth_double }
      auth_double.stub(:url) { 'http://testurl' }
      auth_double.stub(:frob) { 'testfrob' }
      File.stub(:open)
    end

    describe "setup" do
      it "directs the user to setup auth" do
        lib.auth_start.should == 'http://testurl'
      end

      it "stores the frob in configuration" do
        test_stores_in_configuration({:frob=>"testfrob"})
        lib.auth_start
      end
    end

    describe "completion" do
      before do
        YAML.stub(:load_file) { {:frob=>'testfrob'} }
        auth_double.stub(:frob=)
        auth_double.stub(:get_token) {'testtoken'}
      end

      it "loads the frob from the configuration" do
        auth_double.should_receive(:frob=).with('testfrob')
        lib.auth_finish
      end

      it "stores the auth token in the dotfile" do
        test_stores_in_configuration({
                                    :frob=>'testfrob',
                                    :token=>'testtoken'})
        lib.auth_finish
      end
    end
  end
end

def test_stores_in_configuration(config)
  io_double = double('io')
  File.should_receive(:open).and_yield(io_double)
  YAML.should_receive(:dump).with(config, io_double)
end
