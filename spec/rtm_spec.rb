require 'spec_helper'

describe "RTM" do
  let(:lib) { RTM_CLI.new }
  let(:auth_double) { double('auth').as_null_object }
  let(:rtm_double) { double('RTM::RTM').as_null_object }

  before do
    RTM::RTM.stub(:new) { rtm_double }
    rtm_double.stub(:auth) { auth_double }
  end

  context "when config dotfile exists" do
    it "loads the configuration dotfile" do
      ENV['HOME'] = 'testhome'
      YAML.should_receive(:load_file).with('testhome/.rtm') { 
        {:frob=>'testfrob',
         :token=>'testtoken'} }
      auth_double.should_receive(:frob=).with('testfrob')
      rtm_double.should_receive(:token=).with('testtoken')
      lib
    end
  end

  context "when config dotfile does not exist" do
    it "does not crash" do
      lib
    end
  end

  it "returns all incomplete tasks in order of priority then due date" do
    a = {"name"=>"a", "task"=>{"completed"=>"", "priority"=>"1", "due"=>""}}
    b = {"name"=>"b", "task"=>{"completed"=>"", "priority"=>"1",
                                    "due"=>"2011-10-02T02:52:58Z"}}
    c = {"name"=>"c", "task"=>{"completed"=>"", "priority"=>"N",
                                    "due"=>"2012-10-02T02:52:58Z"}}
    d = {"name"=>"d", "task"=>{"completed"=>"", "priority"=>"N",
                                    "due"=>"2011-10-02T02:52:58Z"}}
    RTM::RTM.stub_chain(:new, :tasks, :get_list) { 
      {"tasks"=>{"list"=>[{"id"=>"21242147", "taskseries"=>[
        a, b, c, d,
        {"name"=>"done task", "task"=>{"completed"=>"2011-10-02T02:52:58Z"}}
      ]}, 
      {"id"=>"21242148"}, 
      {"id"=>"21242149"}, 
      {"id"=>"21242150"}, 
      {"id"=>"21242151"}, 
      {"id"=>"21242152"}], 
      "rev"=>"4k555btb3vcwscc8g44sog8kw4ccccc"}, 
      "stat"=>"ok"}
    }
    lib.incomplete_tasks.should == [b, a, d, c]
  end

  describe "authentication" do
    before do
      auth_double.stub(:url) { 'http://testurl' }
      auth_double.stub(:frob) { 'testfrob' }
      File.stub(:open)
    end

    context "when frob exists in config" do
      before do
        YAML.stub(:load_file) { {:frob=>'testfrob'} }
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
        it "stores the auth token in the dotfile" do
          auth_double.stub(:get_token) {'testtoken'}
          test_stores_in_configuration({
                                      :frob=>'testfrob',
                                      :token=>'testtoken'})
          lib.auth_finish
        end
      end
    end
  end
end

def test_stores_in_configuration(config)
  io_double = double('io')
  File.should_receive(:open).and_yield(io_double)
  YAML.should_receive(:dump).with(config, io_double)
end
