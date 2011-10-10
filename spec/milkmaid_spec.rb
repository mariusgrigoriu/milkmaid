require 'spec_helper'

describe "Milkmaid" do
  let(:lib) { Milkmaid.new }
  let(:auth_double) { double('auth').as_null_object }
  let(:rtm_double) { double('rtm').as_null_object }
  let(:timeline_double) { double('timeline').as_null_object }
  let(:tasks_double) { double('tasks') }

  before do
    RTM::RTM.stub(:new) { rtm_double }
    rtm_double.stub(:auth) { auth_double }
    YAML.stub(:load_file).and_return({:token=>'tsttoken'})
    File.stub(:open)
    rtm_double.stub_chain(:timelines, :create) { timeline_double }
    rtm_double.stub(:tasks) { tasks_double }
  end

  context "when config dotfile exists" do
    it "loads the configuration dotfile" do
      ENV['HOME'] = 'testhome'
      YAML.should_receive(:load_file).with('testhome/.milkmaid') { 
        {:frob=>'testfrob',
         :token=>'testtoken'} }
      auth_double.should_receive(:frob=).with('testfrob')
      rtm_double.should_receive(:token=).with('testtoken')
      lib
    end

    it "does not attempt to create a timeline when no auth token exists" do
      YAML.stub(:load_file).and_return({})
      rtm_double.should_not_receive(:timelines)
      lib
    end
  end

  context "when config dotfile does not exist" do
    it "does not crash" do
      YAML.stub(:load_file).and_raise(Errno::ENOENT)
      lib
    end
  end

  describe 'listing lists' do
    let(:a) {{"id"=>"21242147", "name"=>"Inbox", "deleted"=>"0", "locked"=>"1", "archived"=>"0", "position"=>"-1", "smart"=>"0", "sort_order"=>"0"}}

    before do
      rtm_double.stub_chain(:lists, :get_list) {{"stat"=>"ok", "lists"=>{"list"=>a}}}
    end

    it 'returns all lists' do
      lib.lists.should == [a]
    end

    it 'assigns and stores a local ID number for each list' do
      should_store_in_configuration({ :token=>'tsttoken', :lists=>['21242147'] })
      lib.lists
    end
  end
    
  describe "listing tasks" do
    let(:a) {{"name"=>"a", "id"=>"ats", "task"=>{"completed"=>"", "priority"=>"1", 
                                      "id"=>"at", "due"=>""}}}
    let(:b) {{"name"=>"b", "id"=>"bts", "task"=>[
                                      {"completed"=>"2009-10-01", "priority"=>"1",
                                      "id"=>"bt", "due"=>"2011-10-02T02:52:58Z"},
                                      {"completed"=>"", "priority"=>"1",
                                      "id"=>"bt", "due"=>"2011-10-02T02:52:58Z"}]}}
    let(:c) {{"name"=>"c", "id"=>"cts", "task"=>{"completed"=>"", "priority"=>"N",
                                      "id"=>"ct", "due"=>"2012-10-02T02:52:58Z"}}}
    let(:d) {{"name"=>"d", "id"=>"dts", "task"=>{"completed"=>"", "priority"=>"N",
                                      "id"=>"dt", "due"=>"2011-10-02T02:52:58Z"}}}
    let(:response) {
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

    before do
      tasks_double.stub(:get_list).and_return(response)
    end

    context 'when a list number is provided' do
      it 'passes in a list_id if the list number is found' do
        YAML.stub(:load_file) {{
          :token=>'tsttoken',
          :lists=>['tstlistid']
        }}
        tasks_double.should_receive(:get_list).with(:list_id=>'tstlistid')
        lib.incomplete_tasks 1
      end

      it 'does not pass in a list_id if the list number is not found' do
        YAML.stub(:load_file) {{
          :token=>'tsttoken',
          :lists=>['tstlistid']
        }}
        lambda { lib.incomplete_tasks 2 }.should raise_error(Milkmaid::ListNotFound)
      end

      it 'does not pass in a list_id if the list cache does not exist' do
        lambda { lib.incomplete_tasks 2 }.should raise_error(Milkmaid::ListNotFound)
      end
    end

    context 'when a list number is not provided' do
      it 'does not pass in a list_id' do
        tasks_double.should_receive(:get_list).with({})
        lib.incomplete_tasks
      end
    end

    it "returns all incomplete tasks in order of priority then due date" do
      lib.incomplete_tasks.should == [b, a, d, c]
    end

    it "assigns and stores a local ID number to each task for easy addressing" do
      should_store_in_configuration({
        :token=>'tsttoken',
        :tasks=>[
          {:list_id=>'21242147', :taskseries_id=>'bts', :task_id=>'bt'},
          {:list_id=>'21242147', :taskseries_id=>'ats', :task_id=>'at'},
          {:list_id=>'21242147', :taskseries_id=>'dts', :task_id=>'dt'},
          {:list_id=>'21242147', :taskseries_id=>'cts', :task_id=>'ct'}
        ]
      })
      lib.incomplete_tasks
    end
  end

  describe "working with existing tasks" do
    it "raises an error when unable to find the desired task in config" do
      lambda { lib.complete_task 1 }.should raise_error(Milkmaid::TaskNotFound)
      lambda { lib.postpone_task 2 }.should raise_error(Milkmaid::TaskNotFound)
      lambda { lib.delete_task 3 }.should raise_error(Milkmaid::TaskNotFound)
    end

    it "marks the task as complete" do
      should_call_rtm_api(:complete, 1)
      lib.complete_task 1
    end

    it "postpones a task" do
      should_call_rtm_api(:postpone, 2)
      lib.postpone_task 2
    end

    it "deletes a task" do
      should_call_rtm_api(:delete, 3)
      lib.delete_task 3
    end
  end

  it "adds a task to the inbox using Smart Add" do
    tasks_double.should_receive(:add).with(:name=>'TestName', :parse=>'1',
                                           :timeline=>timeline_double)
    lib.add_task 'TestName'
  end

  describe "authentication" do
    before do
      auth_double.stub(:url) { 'http://testurl' }
      auth_double.stub(:frob) { 'testfrob' }
      File.stub(:open)
    end


    describe "setup" do
      before do
        YAML.stub(:load_file).and_raise(Errno::ENOENT)
      end

      it "directs the user to setup auth" do
        lib.auth_start.should == 'http://testurl'
      end

      it "stores the frob in configuration" do
        should_store_in_configuration({:frob=>"testfrob"})
        lib.auth_start
      end
    end

    describe "completion" do
      it "stores the auth token in the dotfile" do
        YAML.stub(:load_file) { {:frob=>'testfrob'} }
        auth_double.stub(:get_token) {'testtoken'}
        should_store_in_configuration({
                                    :frob=>'testfrob',
                                    :token=>'testtoken'})
        lib.auth_finish
      end
    end
  end

  it 'cleans out the cache' do
    YAML.stub(:load_file) {{ :token=>'tsttoken', 'junk'=>'trash' }}
    should_store_in_configuration({:token=>'tsttoken'})
    lib.clean
  end
end

def should_store_in_configuration(config)
  io_double = double('io')
  File.should_receive(:open).and_yield(io_double)
  YAML.should_receive(:dump).with(config, io_double)
end

def should_call_rtm_api(method, tasknum)
  YAML.stub(:load_file) {{
    :token=>'tsttoken',
    :tasks=>(0...tasknum).collect do |n| 
      {:list_id=>"#{n+1}l", :taskseries_id=>"#{n+1}ts", :task_id=>"#{n+1}t"}
    end
  }}
  tasks_double.should_receive(method).with(
    :list_id=>"#{tasknum}l", :taskseries_id=>"#{tasknum}ts", 
    :task_id=>"#{tasknum}t", :timeline=>timeline_double)
end
