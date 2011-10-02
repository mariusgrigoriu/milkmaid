require 'moocow'

class RTM_CLI
  def initialize
    @rtm = RTM::RTM.new(RTM::Endpoint.new('31308536ffed80061df846c3a4564a27', 'c1476318e3483441'))
    begin
      @config_file = File.join(ENV['HOME'], '.rtm')
      @config = YAML.load_file(@config_file)
      @auth = @rtm.auth
      @auth.frob = @config[:frob]
      @rtm.token = @config[:token]
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
          entries << taskseries if taskseries['task']['completed'].empty?
        end
      end
    end
    entries.sort! do |a, b|
      result = a['task']['priority'] <=> b['task']['priority']
      if result == 0
        if a['task']['due'].empty?
          1
        elsif b['task']['due'].empty?
          -1
        else
          Time.parse(a['task']['due']) <=> Time.parse(b['task']['due'])
        end
      else
        result
      end
    end
    entries.each_with_index do |taskseries, i|
      @config["#{i+1}list_id"] = taskseries['list_id']
      @config["#{i+1}taskseries_id"] = taskseries['id']
      @config["#{i+1}task_id"] = taskseries['task']['id']
    end
    save_config
    entries
  end

  def complete_task(tasknum)
    raise TaskNotFound
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

  private
  def save_config
    File.open(@config_file, 'w') { |f| YAML.dump(@config, f) }
  end
end
