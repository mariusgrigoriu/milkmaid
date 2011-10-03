#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'main'
require 'paint'
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
        rtm.incomplete_tasks.each_with_index do |taskseries, i|
          text = "#{i+1}: #{taskseries['name']}"
          text << "(R)" unless taskseries['rrule'].nil?
          text << " #{Time.parse(taskseries['task']['due']).getlocal.strftime(
          "%A %b %d, %Y %I:%M %p")}" unless taskseries['task']['due'].empty?
          text << " ##{taskseries['id']}"
          color = {
            '1'=>[234, 82, 0], 
            '2'=>[0, 96, 191], 
            '3'=>[53, 154, 255], 
            'N'=>:nothing
          }
          puts Paint[text, color[taskseries['task']['priority']]]
        end
      rescue RTM::NoTokenException
        puts "Authentication token not found. Run `#{__FILE__} auth start`"
      end
    end
  end

  mode :complete do
    argument(:tasknum) {
      cast :int
    }

    def run
      begin
        rtm.complete_task params['tasknum'].value
      rescue RTM_CLI::TaskNotFound
        puts "Task ##{params['tasknum'].value} not found. Run `#{__FILE__} list` " +
          "to load a list of tasks."
      rescue RTM::NoTokenException
        puts "Authentication token not found. Run `#{__FILE__} auth start`"
      end
    end
  end

  mode :postpone do
    argument(:tasknum) {
      cast :int
    }

    def run
      begin
        rtm.postpone_task params['tasknum'].value
      rescue RTM_CLI::TaskNotFound
        puts "Task ##{params['tasknum'].value} not found. Run `#{__FILE__} list` " +
          "to load a list of tasks."
      rescue RTM::NoTokenException
        puts "Authentication token not found. Run `#{__FILE__} auth start`"
      end
    end
  end

  mode :add do
    argument(:taskname) 

    def run
      begin
        rtm.add_task params['taskname'].value
      rescue RTM::NoTokenException
        puts "Authentication token not found. Run `#{__FILE__} auth start`"
      end
    end
  end
        
  mode :auth do
    mode :start do
      def run
        puts '1. Visit the URL to authorize the application to access your account.'
        puts "2. Run `#{__FILE__} auth finish`"
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
          puts "Invalid frob. Did you visit the link from `#{__FILE__} auth start`?"
        rescue RuntimeError
          puts "Frob does not exist. Did you run `#{__FILE__} auth start`?"
        end
      end
    end
  end
}
