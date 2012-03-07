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
require 'forwardable'
require File.dirname(__FILE__)+'/utils'

module MingleConnector

  class Jira
    def initialize api, logger, config
      @logged_in = false
      @jira_api = api
      @logger = logger
      @user = config[:user]
      @password = config[:password]
      @development_status_field = config[:mingle_dev_status_field]
      @transitions = config[:transitions]
    end

    def update_development_status issue_key, development_status
      if @development_status_field
        update_issue issue_key, @development_status_field, development_status
      else
        @logger.development_status_not_defined(issue_key)
      end
    end

    def handback issue
      login_if_necessary
      transition = transition_for(issue)
      @jira_api.transition_issue(issue, transition_for(issue))
      @logger.jira_issue_transitioned(issue, transition_for(issue))
    end

    def validate
      login_if_necessary
    end

    private
    def transition_for issue
      project = project_key_of(issue)
      @transitions[project] or raise UnknownProject.new(project)
    end

    def project_key_of issue
      issue.split('-').first
    end

    def update_issue issue, field, value
      login_if_necessary
      @jira_api.update_issue issue, "customfield_#{field}", value
      @logger.jira_issue_updated issue, field, value
    end

    def login_if_necessary
      return if @logged_in
      @jira_api.login(@user, @password)
      @logged_in = true
    end

    class UnknownProject < Exception
      def initialize(key) @key=key end
      def log logger
        logger.unknown_jira_project(@key)
      end
    end
  end

  class JiraAPI
    Utils.load_gems 'soap4r-1.5.8', 'jira4r-0.3.0', 'jruby-openssl-0.6', 'httpclient-2.1.5.2'
    require 'jira4r'
    include Jira4R::V2
    def initialize(location)
      @location = location
      @jira_tool = Jira4R::JiraTool.new(2, @location)
      @jira_tool.logger = DummyLogger.new
    end

    def login user, password
      begin
        @jira_tool.login user, password
      rescue SocketError
        raise JiraHostNotFoundError.new @location
      rescue Errno::ECONNREFUSED
        raise JiraHostNotFoundError.new @location
      rescue SOAP::FaultError => ex
        if ex.message.include? "RemoteAuthenticationException: Invalid username or password."
          raise InvalidJiraCredentialsError
        else
          raise
        end
      end
    end

    def update_issue issue, field, value
      begin
        @jira_tool.updateIssue(issue, [RemoteFieldValue.new(field, value)])
      rescue SOAP::FaultError => e
        if e.message.include? 'RemotePermissionException: This issue does not exist'
          raise IssueDoesNotExistError.new issue
        else
          raise
        end
      end
    end

    def transition_issue key, transition_name
      actions = @jira_tool.getAvailableActions(key) || []
      transition = actions.find { |transition| transition.name.downcase == transition_name.downcase }
      transition or raise InvalidJIRATransition.new(transition_name, key)
      @jira_tool.progressWorkflowAction(key, transition.id, [])
    rescue SOAP::FaultError => e
      if e.message.include? 'RemotePermissionException: This issue does not exist'
        raise IssueDoesNotExistError.new key
      else
        raise
      end
    end

    private
    class DummyLogger
      def method_missing(meth_id, *args, &block)
      end
    end
  end

  class LoggingJiraAPI
    include Decorator
    def initialize logger
      @logger = logger
    end

    def login name, password
      @logger.jira_login_before name
      response = wrapped.login name, password
      @logger.jira_login_after
      response
    end

    def update_issue issue, field, value
      @logger.jira_update_issue_before issue, field, value
      response = wrapped.update_issue issue, field, value
      @logger.jira_update_issue_after
      response
    end

    def transition_issue issue, transition
      @logger.jira_transition_issue_before issue, transition
      response = wrapped.transition_issue issue, transition
      @logger.jira_transition_issue_after
      response
    end
  end

  class ResponseCheckingJiraApi
    extend Forwardable
    include Decorator
    def_delegators :wrapped, :login, :transition_issue

    def update_issue(issue, field, value)
      response = wrapped.update_issue(issue, field, value)
      raise InvalidJIRAField.new(field, issue) unless contains_field(field, response)
      response
    end

    private
    def contains_field(field, response)
      response.customFieldValues.find { |f| f.customfieldId == field }
    end
  end

  class JiraHostNotFoundError < Exception
    attr_reader :location

    def initialize location
      @location = location
    end
  end

  class InvalidJiraCredentialsError < Exception
  end

  class IssueDoesNotExistError < Exception
    attr_reader :issue_key
    def initialize issue_key
      @issue_key = issue_key
    end
  end

  class InvalidJIRAField < Exception
    attr_reader :field, :issue
    def initialize(field, issue) @field = field; @issue = issue end
    def message() "Field #{field} not found on issue #{issue}." end
  end

  class InvalidJIRATransition < Exception
    attr_reader :key, :name
    def initialize(name, key) @name, @key = name, key end
    def message() "Transition #{@name} does not exist or is not applicable for issue #{@key}." end
  end
end

