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
      begin
        rtm.incomplete_tasks do |taskseries|
          print "#{taskseries['name']}"
          print "(R)" unless taskseries['rrule'].nil?
          print " #{Time.parse(taskseries['task']['due']).getlocal.strftime(
          "%A %b %d, %Y %I:%M %p")}\n"
        end
      rescue RTM::NoTokenException
        puts "Authentication token not found. Run `#{__FILE__} auth start`"
      end
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
        begin
          rtm.auth_finish
          puts 'Authentication token saved.'
        rescue RTM::VerificationException
          puts 'Invalid frob. Did you visit the link from `rtm auth start`?'
        rescue RuntimeError
          puts "Frob does not exist. Did you run `#{__FILE__} auth start`?"
        end
      end
    end
  end
}
