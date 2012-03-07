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
require File.dirname(__FILE__) + '/spec_helper'
load_files 'logging', 'config', 'web_client', 'jira', 'mingle/mingle'

include MingleConnector
describe 'Logging' do
  before do
    @status_property_name = 'Defect Status'
    @logger=Logging.new({:filename=>'mingle-jira-connector.log', :level=>'ALL', :exceptions_filename => 'exceptions.log'})
  end

  def logs
    IO.read('mingle-jira-connector.log')
  end

  def exceptions
    IO.read('exceptions.log')
  end

  context "when a log level is specified" do
    it "should ask log4j to set the logging level" do
      mock_logger = StubLog4jLogger.new
      mock_level = mock
      org.apache.log4j.Logger.stub!(:getLogger).and_return mock_logger
      org.apache.log4j.Level.stub!(:toLevel).with('LEVEL').and_return mock_level
      mock_logger.should_receive(:setLevel).with(mock_level)
      logger = Logging.new({:level=>'LEVEL', :filename=>'mingle-jira-connector.log', :exceptions_filename => 'exceptions.log'})
    end
  end

  it 'logs at warn level stating that the application started' do
    @logger.application_started
    logs.should match("WARN.*Application started")
  end

  it "logs at warnlevel that the application has stopped" do
    @logger.application_stopped
    logs.should match("WARN.*Application stopped")
  end

  describe "event processing" do
    it "delegates dispatch to the event" do
      event = mock 'event'
      event.should_receive(:log).with @logger
      @logger.processing_event event
    end

    describe "status changed event" do
      it "logs at info level" do
        @logger.processing_status_changed_event nil, @status_property_name
        logs.should match 'INFO'
      end
      it "logs the type of event" do
        @logger.processing_status_changed_event nil, @status_property_name
        logs.should match "#{@status_property_name} changed"
      end
      it "logs the card number" do
        @logger.processing_status_changed_event 'the-card', @status_property_name
        logs.should match 'the-card'
      end
    end

    describe "uninteresting event" do
      it "logs at info level" do
        @logger.processing_uninteresting_event(nil)
        logs.should match 'INFO'
      end
      it "logs that the event is unrecognized" do
        @logger.processing_uninteresting_event(nil)
        logs.should match 'uninteresting'
      end
      it "logs the id" do
        @logger.processing_uninteresting_event('ss22f')
        logs.should match('ss22f')
      end
    end

    it "logs at info level when the issue key can't be found" do
      @logger.issue_key_missing('the-project', '42')
      logs.should match "INFO.*Event ignored as there was no JIRA issue key in Mingle card the-project/#42."
    end
  end

  describe "interacting with Mingle" do
    it "logs at error level that a card could not be found" do
      @logger.card_not_found 'the-project', '25'
      logs.should match("ERROR.*Mingle card the-project/#25 could not be found.")
    end

    describe "fatal mingle error" do
      it "should log at fatal level" do
        @logger.fatal_mingle_error(HttpResponseError.new(nil, nil, nil))
        logs.should include("FATAL")
      end

      it "logs status code" do
        @logger.fatal_mingle_error(HttpResponseError.new(nil, 404, nil))
        logs.should include("404")
      end

      it "logs response body" do
        err_str = "I am\na multiline\nerror"
        log_str = "I am;a multiline;error"
        @logger.fatal_mingle_error(HttpResponseError.new(nil, nil, err_str))
        logs.should include(log_str)
      end

      it "logs url requested" do
        @logger.fatal_mingle_error(HttpResponseError.new("http://foo:bar", nil, nil))
        logs.should include("http://foo:bar")
      end
    end
  end

  describe "interacting with Jira" do
    it 'logs at info level that jira issue has been updated' do
      @logger.jira_issue_updated('ABC-123', 'Mingle URL', 'http://localhost:9090')
      logs.should match("INFO.*Updated jira issue ABC-123")
    end

    it "logs at debug level that a status update was ignored because the field isn't defined" do
      @logger.development_status_not_defined('the-key')
      logs.should match("DEBUG.*the-key")
    end

    it "logs that an issue has ben transitioned" do
      @logger.jira_issue_transitioned('the-key', 'the-transition')
      logs.should match("INFO.*the-transition.*the-key")
    end

    describe "logging jira host not found" do
      it "logs at fatal level" do
        @logger.jira_host_not_found JiraHostNotFoundError.new nil
        logs.should include 'FATAL'
      end

      it "logs the host" do
        @logger.jira_host_not_found JiraHostNotFoundError.new 'http://foo:8081'
        logs.should include 'http://foo:8081'
      end
    end

    describe "logging invalid jira credentials" do
      it "logs at fatal level" do
        @logger.invalid_jira_credentials InvalidJiraCredentialsError.new
        logs.should include 'FATAL'
      end
    end

    describe "logging missing issues" do
      it "logs at error level" do
        @logger.issue_missing IssueDoesNotExistError.new nil
        logs.should include 'INFO'
      end
      it "logs the issue id" do
        @logger.issue_missing IssueDoesNotExistError.new 'issue-key'
        logs.should include 'issue-key'
      end
    end

    it "logs unknown projects at fatal level" do
      @logger.unknown_jira_project 'PROJ'
      logs.should match 'FATAL.*PROJ.*'
    end

    describe "logging invalid transitions" do
      it "logs at error level" do
        @logger.invalid_transition InvalidJIRATransition.new(nil, nil)
        logs.should include 'ERROR'
      end
      it "logs the issue key" do
        @logger.invalid_transition InvalidJIRATransition.new('the-key', nil)
        logs.should include 'the-key'
      end
      it "logs the transition" do
        @logger.invalid_transition InvalidJIRATransition.new(nil, 'the-transition')
        logs.should include 'the-transition'
      end
    end

    describe "logging invalid field" do
      it "logs at fatal level" do
        @logger.invalid_jira_field(InvalidJIRAField.new(nil, nil))
        logs.should include 'FATAL'
      end

      it "logs the field id" do
        @logger.invalid_jira_field InvalidJIRAField.new('the-field', nil)
        logs.should include 'the-field'
      end

      it "logs the issue id" do
        @logger.invalid_jira_field InvalidJIRAField.new(nil, 'the-issue')
        logs.should include 'the-issue'
      end
    end

    describe "API logging" do
      describe "login" do
        describe "before" do
          it "logs at debug level" do
            @logger.jira_login_before nil
            logs.should match "DEBUG"
          end
          it "logs the operation" do
            @logger.jira_login_before nil
            logs.should match "before JIRA login"
          end
          it "logs the name" do
            @logger.jira_login_before 'bob'
            logs.should match 'bob'
          end
        end
        describe "after" do
          it "logs at debug level" do
            @logger.jira_login_after
            logs.should match "DEBUG"
          end
          it "logs the operation" do
            @logger.jira_login_after
            logs.should match "after JIRA login"
          end
        end
      end
      describe "update issue" do
        describe "before" do
          it "logs at debug level" do
            @logger.jira_update_issue_before nil, nil, nil
            logs.should match "DEBUG"
          end
          it "logs the operation" do
            @logger.jira_update_issue_before nil, nil, nil
            logs.should match "before JIRA update_issue"
          end
          it "logs the parameters" do
            @logger.jira_update_issue_before 'the-issue', 'the-field', 'the-value'
            logs.should match 'the-issue'
            logs.should match 'the-field'
            logs.should match 'the-value'
          end
        end
        describe "after" do
          it "logs at debug level" do
            @logger.jira_update_issue_after
            logs.should match "DEBUG"
          end
          it "logs the operation" do
            @logger.jira_update_issue_after
            logs.should match "after JIRA update_issue"
          end
        end
      end

      describe "transition issue" do
        describe "before" do
          it "logs at debug level" do
            @logger.jira_transition_issue_before nil, nil
            logs.should match "DEBUG"
          end
          it "logs the operation" do
            @logger.jira_transition_issue_before nil, nil
            logs.should match "before JIRA transition_issue"
          end
          it "logs the parameters" do
            @logger.jira_transition_issue_before 'the-issue', 'the-transition'
            logs.should match 'the-issue'
            logs.should match 'the-transition'
          end
        end
        describe "after" do
          it "logs at debug level" do
            @logger.jira_transition_issue_after
            logs.should match "DEBUG"
          end
          it "logs the operation" do
            @logger.jira_transition_issue_after
            logs.should match "after JIRA transition_issue"
          end
        end
      end
    end
  end

  describe "error handling" do
    it "logs fatal errors at fatal level" do
      @logger.fatal_error raised_exception
      logs.should include 'FATAL'
    end

    it "logs the error's message" do
      @logger.fatal_error raised_exception 'foo'
      logs.should include 'foo'
    end

    it "points the reader to the exception log" do
      @logger.fatal_error raised_exception
      logs.should include 'See exceptions.log for more details.'
    end

    it "logs the exceptions in the file passed" do
      logger = Logging.new({:filename=>'mingle-jira-connector.log', :level=>'ALL', :exceptions_filename => 'exception.log'})
      @logger.fatal_error raised_exception 'foo'
      IO.read('exception.log').should include 'foo'
    end

    it "prints the message exceptions.log" do
      @logger.fatal_error raised_exception 'foo'
      exceptions.should include 'foo'
    end

    it "prints the stack trace to exceptions.log" do
      error = raised_exception
      @logger.fatal_error error
      error.backtrace[1..5].each { |line| exceptions.should include line }
    end
  end

  describe "webclient logs" do
    it "should log at debug level the url of the get request" do
      @logger.webclient_get_before 'the-url'
      logs.should match /DEBUG.*before WebClient\.get.*the-url/
    end

    it "should log at debug level the response of the get request" do
      response = WebClient::Response.new 200, "this\nis\na\nbody", {}
      @logger.webclient_get_after response
      logs.should match /DEBUG.*after WebClient\.get -- status: 200, body: this;is;a;body/
    end

    it "should log at debug level the url and params of the post request" do
      @logger.webclient_post_before 'the-url', {'foo'=>'the foo', 'bar'=>'1'}
      params = 'params: {"foo"=>"the foo", "bar"=>"1"}'
      logs.should match /DEBUG.*before WebClient\.post.*the-url.*#{params}/
    end

    it "should log at debug level the response of the post request" do
      response = WebClient::Response.new 200, "this\nis\na\nbody", {}
      @logger.webclient_post_after response
      logs.should match /DEBUG.*after WebClient\.post -- status: 200, body: this;is;a;body/
    end
  end

  describe "bookmarking logs" do
    it "should log at info level the newly bookmarked project" do
      @logger.bookmarking_a_new_project 'new-project'
      logs.should match /INFO.*[Bb]ookmark.*new-project/
    end
  end

  it "tells the exception to log itself" do
    exception = mock('exception')
    exception.should_receive(:log).with(@logger)
    @logger.log_exception(exception)
  end

  describe "config validation error logging" do
    it "logs missing config entries" do
      @logger.missing_config('the-section', 'the-entry')
      logs.should match(/FATAL.*Configuration error occured: the-section.the-entry is missing./)
    end

    it "logs unexpected config entries" do
      @logger.unexpected_config('the-section', 'the-entry')
      logs.should match(/FATAL.*Configuration error occured: the-section.the-entry is unexpected./)
    end

    it "logs duplicate config entries" do
      @logger.duplicate_config('the-section', 'the-entry')
      logs.should match(/FATAL.*Configuration error occured: the-section.the-entry is defined in more than one place./)
    end
  end

  context "another process running" do
    it "logs at fatal level that there is another instance running" do
      @logger.another_instance_running
      logs.should match(/FATAL.* Mingle-JIRA Connector not starting. There is another instance of the Connector running./)
    end
  end

  after(:each) do
    File.delete('mingle-jira-connector.log')
  end

  after(:each) do
    File.delete('exception.log') if File.exists? 'exception.log'
  end

  after(:each) do
    File.delete('exceptions.log') if File.exists? 'exceptions.log'
  end

  after(:all) { org.apache.log4j.LogManager.shutdown }
end

describe Exception do
  it "tells the logger to log as fatal" do
    logger = mock('logger')
    e = Exception.new
    logger.should_receive(:fatal_error).with e
    e.log logger
  end
end
