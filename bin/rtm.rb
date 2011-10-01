#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'main'
require 'rtm'

def rtm
  @rtmcli ||= RTM_CLI.new
end

Main {
  def run
    help!
  end

  mode :list do
    def run
      
    end
  end

  mode :auth do
    mode :start do
      def run
        puts '1. Visit the URL to authorize the application to access your account.'
        puts '2. Run `rtm auth finish`'
        puts
        puts rtm.auth_start
      end
    end

    mode :finish do
      def run
        rtm.auth_finish
        puts 'Authentication token saved.'
      end
    end
  end
}
