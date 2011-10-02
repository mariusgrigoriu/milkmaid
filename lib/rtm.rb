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
    @rtm.tasks.get_list['tasks']['list'].as_array.each do |items|
      next if items['taskseries'].nil?
      items['taskseries'].as_array.each do |taskseries|
        yield taskseries if taskseries['task']['completed'].empty?
      end
    end
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

  private
  def save_config
    File.open(@config_file, 'w') { |f| YAML.dump(@config, f) }
  end
end
