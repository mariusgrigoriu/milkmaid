require 'moocow'

class Milkmaid
  def initialize
    @rtm = RTM::RTM.new(RTM::Endpoint.new('31308536ffed80061df846c3a4564a27', 'c1476318e3483441'))
    @auth = @rtm.auth
    begin
      @config_file = File.join(ENV['HOME'], '.milkmaid')
      @config = YAML.load_file(@config_file)
      @auth.frob = @config[:frob]
      @rtm.token = @config[:token]
      @timeline = @rtm.timelines.create['timeline'] unless @config[:token].nil?
    rescue Errno::ENOENT
      @config = {}
    end
  end

  def lists
    entries = @rtm.lists.get_list['lists']['list'].as_array
    list_ids = entries.map { |list| list['id'] }
    @config[:lists] = list_ids
    save_config
    entries
  end
  
  def incomplete_tasks(list=nil)
    params = {}
    unless list.nil?
      if @config[:lists]
        list = @config[:lists][list-1]
        params[:list_id] = list unless list.nil?
      end
      raise ListNotFound if params.empty?
    end
    entries = []
    list_id = nil
    @rtm.tasks.get_list(params)['tasks']['list'].
      as_array.each do |items|
      list_id = items['id']
      if !items['taskseries'].nil?
        items['taskseries'].as_array.each do |taskseries|
          taskseries['list_id'] = list_id
          entries << taskseries if Milkmaid::last_task(taskseries)['completed'].empty?
        end
      end
    end
    entries.sort! do |a, b|
      taska = Milkmaid::last_task a
      taskb = Milkmaid::last_task b
      result = taska['priority'] <=> taskb['priority']
      if result == 0
        if taska['due'].empty?
          1
        elsif taskb['due'].empty?
          -1
        else
          Time.parse(taska['due']) <=> Time.parse(taskb['due'])
        end
      else
        result
      end
    end
    @config[:tasks] = entries.map do |taskseries|
      {:list_id => taskseries['list_id'], 
      :taskseries_id => taskseries['id'],
      :task_id => Milkmaid::last_task(taskseries)['id']}
    end
    save_config
    entries
  end

  def complete_task(tasknum)
    check_task_ids tasknum
    call_rtm_api :complete, tasknum
  end

  def postpone_task(tasknum)
    check_task_ids tasknum
    call_rtm_api :postpone, tasknum
  end

  def delete_task(tasknum)
    check_task_ids tasknum
    call_rtm_api :delete, tasknum
  end

  def add_task(name)
    @rtm.tasks.add :name=>name, :parse=>'1', :timeline=>@timeline
  end
  
  def auth_start
    url = @auth.url
    @config[:frob] = @auth.frob
    save_config
    url
  end

  def auth_finish
    @config[:token] = @auth.get_token
    save_config
  end

  def clean
    @config.delete_if { |k| k != :token }
    save_config
  end

  class TaskNotFound < StandardError
  end

  class ListNotFound < StandardError
  end

  private
  def self.last_task(taskseries)
    taskseries['task'].as_array.last
  end

  def save_config
    File.open(@config_file, 'w') { |f| YAML.dump(@config, f) }
  end

  def check_task_ids(tasknum)
    raise TaskNotFound if @config[:tasks].nil? || @config[:tasks][tasknum-1].nil? 
  end

  def call_rtm_api(method, tasknum)
    @rtm.tasks.send method, @config[:tasks][tasknum-1].merge(:timeline=>@timeline)
  end
end
