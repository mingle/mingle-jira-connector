# Copyright 2011 ThoughtWorks, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You may
# obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
# 
require File.dirname(__FILE__)+'/spec_helper'
load_files('jira', 'application', 'environment')

include MingleConnector
describe Application do
  def application
    Application.new(event_source, logger, event_processor, environment)
  end
  def event_source() @event_source ||= StubEventSource.new events end
  def events() @events ||= [an_event] end
  def logger() @logger ||= StubLogger.new end
  def event_processor() @event_processor ||= StubEventProcessor.new end
  def config() @config ||= StubConfig.new end
  def environment() @environment ||= Environment.new config end

  it "should ask the EventSource for events" do
    event_source.should_receive(:events).and_return([])
    application.run
  end

  it "should validate the environment" do
    environment.should_receive :validate
    application.run
  end

  it "tells the logger that it has started even if any config is missing" do
    logger.should_receive(:application_started)
    begin
      application.run
    rescue Exception
    end
  end

  it "tells the logger that it has stopped even if there is an error" do
    logger.should_receive(:application_stopped)
    event_source.stub!(:events).and_throw('error')
    begin
      application.run
    rescue Exception
    end
  end

  describe "handling errors" do
    context "event source raises an error" do
      context "when getting events" do
        before { @event_source = FailingEventSource.new }

        it "passes the error to the logger" do
          logger.should_receive(:log_exception).with(FailingEventSource.error)
          application.run
        end
      end
    end

    context "config validation raises an error" do
      it "calls the logger" do
        @config = ValidationFailingConfig.new
        logger.should_receive(:log_exception).with(config.error)
        application.run
      end
    end

    context "event processing causes an error" do
      def event_processor() @event_processor ||= ErrorRaisingEventProcessor.new(@error) end

      [{:error=>InvalidJIRAField.new(nil, nil), :log_method=>:invalid_jira_field},
       {:error=>InvalidJiraCredentialsError.new(nil, nil), :log_method=>:invalid_jira_credentials},
       {:error=>HttpResponseError.new(nil, nil, nil), :log_method=>:fatal_mingle_error},
       {:error=>JiraHostNotFoundError.new(nil), :log_method=>:jira_host_not_found}
      ].each do |error|
        describe error do
          before { @error = error[:error] }

          it "isn't propogated" do
            lambda { application.run }.should_not raise_error
          end

          it "is logged" do
            logger.should_receive(error[:log_method]).with event_processor.error
            application.run
          end

          it "doesn't try to handle any more events" do
            @events = [an_event, an_event]
            event_processor.should_receive(:process).once.and_raise @error
            application.run
          end
        end
      end
    end
  end
end

def an_event() {} end

class FailingEventSource
  def events
    raise self.class.error
  end
  def self.error
    @error ||= Exception.new
  end
end

class StubConfig
  def validate() end
end

class ValidationFailingConfig
  def error() @error ||= MingleConnector::Config::InvalidConfig.new [] end
  def validate() raise error end
end

class ErrorRaisingEventProcessor
  attr_reader :error
  def initialize(error) @error = error end
  def process(event) raise error end
end

class StubEventSource
  def initialize(events = [])
    events = [events] unless events.respond_to? :each
    @events = events
  end

  def events
    @events
  end
end

class StubEventProcessor
  def process(event) end
  def cards_created() 0 end
end
