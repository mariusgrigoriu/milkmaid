require 'moocow'

class RTM_CLI
  def initialize
    begin
      @config_file = File.join(ENV['HOME'], '.rtm')
      @config = YAML.load_file(@config_file)
    rescue Errno::ENOENT
      @config = {}
    end
    @rtm = RTM::RTM.new(RTM::Endpoint.new('31308536ffed80061df846c3a4564a27', 'c1476318e3483441'))
  end

  def list
    @rtm.tasks.get_list.as_array
  end

  def auth_start
    auth = @rtm.auth
    url = auth.url
    @config[:frob] = auth.frob
    save_config
    url
  end

  def auth_finish
    auth = @rtm.auth
    auth.frob = @config[:frob]
    @config[:token] = auth.get_token
    save_config
  end

  private
  def save_config
    File.open(@config_file, 'w') { |f| YAML.dump(@config, f) }
  end
end
