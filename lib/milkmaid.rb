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

  def incomplete_tasks
    entries = []
    list_id = nil
    @rtm.tasks.get_list['tasks']['list'].as_array.each do |items|
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
    entries.each_with_index do |taskseries, i|
      @config["#{i+1}list_id"] = taskseries['list_id']
      @config["#{i+1}taskseries_id"] = taskseries['id']
      @config["#{i+1}task_id"] = Milkmaid::last_task(taskseries)['id']
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

  class TaskNotFound < StandardError
  end

  def self.last_task(taskseries)
    taskseries['task'].as_array.last
  end

  private
  def save_config
    File.open(@config_file, 'w') { |f| YAML.dump(@config, f) }
  end

  def check_task_ids(tasknum)
    raise TaskNotFound if @config["#{tasknum}list_id"].nil? || 
                          @config["#{tasknum}taskseries_id"].nil? ||
                          @config["#{tasknum}task_id"].nil?
  end

  def call_rtm_api(method, tasknum)
    @rtm.tasks.send method, :list_id=>@config["#{tasknum}list_id"],
                        :taskseries_id=>@config["#{tasknum}taskseries_id"],
                        :task_id=>@config["#{tasknum}task_id"],
                        :timeline=>@timeline
  end
end
