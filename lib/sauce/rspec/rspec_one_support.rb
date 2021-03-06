require 'sauce/utilities'
require "sauce_whisk"

begin
  require 'spec'
  # any gem could export a require as 'spec' so we must explicitly check
  # to see if the expected rspec 1 class has loaded.
  raise LoadError unless defined?(Spec::Example::ExampleGroup)
  module Sauce
    module RSpec
      class SeleniumExampleGroup < Spec::Example::ExampleGroup
        attr_reader :selenium
        @@need_tunnel = false

        def self.inherited(subclass)
          # only setup tunnel if somebody needs it
          @@need_tunnel = true
          super(subclass)
        end

        before :suite do
          config = Sauce::Config.new
          if @@need_tunnel
            if config[:application_host]
              Sauce::Utilities::Connect.start(:host => config[:application_host], :port => config[:application_port])
            end
            if config[:start_local_application] &&
              Sauce::Utilities::RailsServer.is_rails_app?
              @@server = Sauce::Utilities::RailsServer.new
              @@server.start
            end
          end
        end

        after :suite do
          Sauce::Utilities::Connect.close
          @@server.stop if defined? @@server
        end

        def execute(*args)
          config = Sauce::Config.new
          description = [self.class.description, self.description].join(" ")
          config[:browsers].each do |os, browser, version|
            @selenium = Sauce::Selenium2.new({:os => os, :browser => browser,
                                              :browser_version => version,
                                              :job_name => description})

            begin
              success = super(*args)
              SauceWhisk::Jobs.change_status @selenium.session_id, success
            ensure
              @selenium.stop
            end
          end
        end

        alias_method :page, :selenium
        alias_method :s, :selenium

        Spec::Example::ExampleGroupFactory.register(:selenium, self)
      end
    end
  end
rescue LoadError
  # User doesn't have RSpec 1.x installed
rescue => e
  STDERR.puts "Exception occured: #{e.to_s}"
  exit 1
end
