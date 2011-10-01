#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'main'
require 'rtm'

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
        rtmcli = RTM_CLI.new
        puts '1. Visit the URL to authorize the application to access your account.'
        puts '2. Run `rtm auth finish`'
        puts
        puts rtmcli.auth
      end
    end
  end
}
