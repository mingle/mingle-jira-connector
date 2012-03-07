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
require 'java'
require 'vendor/jars/log4j-1.2.15.jar'

module MingleConnector
  class Logging
    def self.log_to_stdout
      layout = org.apache.log4j.PatternLayout.new '%p %m%n'
      appender = org.apache.log4j.ConsoleAppender.new(layout)

      logger = org.apache.log4j.Logger.getLogger 'mingle-jira-connector'
      logger.addAppender(appender)
      exceptions = org.apache.log4j.Logger.getLogger 'exceptions'
      exceptions.addAppender(appender)
    end

    def initialize(config)
      @logger = org.apache.log4j.Logger.getLogger 'mingle-jira-connector'
      @logger.setLevel(org.apache.log4j.Level.toLevel(config[:level]))
      log_into_file(config[:filename], @logger)

      @exceptions = org.apache.log4j.Logger.getLogger 'exceptions'
      log_into_file config[:exceptions_filename], @exceptions
    end

    def application_started
      @logger.warn("Application started")
    end

    def jira_issue_updated issue_key, field, value
      @logger.info("Updated jira issue #{issue_key}")
    end

    def development_status_not_defined issue_key
      @logger.debug("Not propogating development status change to #{issue_key} because the JIRA custom field is not defined.")
    end

    def jira_issue_transitioned issue_key, transition
      @logger.info("Applied transition '#{transition}' to JIRA issue #{issue_key}.")
    end

    def jira_host_not_found error
      @logger.fatal "Jira host could not be found #{error.location}."
    end

    def invalid_jira_credentials error
      @logger.fatal "The configured Jira credentials are invalid."
    end

    def issue_missing e
      @logger.info "Received an event for an issue (#{e.issue_key}) which could not be found. Perhaps it has been deleted in JIRA."
    end

    def unknown_jira_project key
      @logger.fatal "Cannot find JIRA project #{key} in configuration"
    end

    def invalid_transition e
      @logger.error "The JIRA transition '#{e.name}' could not be applied to the issue #{e.key}. This may indicate that your configuration is incorrect, or that someone has manually applied the transition already."
    end

    def invalid_jira_field e
      @logger.fatal "Could not find custom field #{e.field} in issue #{e.issue}."
    end

    def jira_login_before name
      @logger.debug "before JIRA login - name: #{name}"
    end

    def jira_login_after
      @logger.debug "after JIRA login"
    end

    def jira_update_issue_before issue, field, value
      @logger.debug "before JIRA update_issue - issue: #{issue}, field: #{field}, value: #{value}"
    end

    def jira_update_issue_after
      @logger.debug "after JIRA update_issue"
    end

    def jira_transition_issue_before issue, transition
      @logger.debug "before JIRA transition_issue - issue: #{issue}, transition: #{transition}"
    end

    def jira_transition_issue_after
      @logger.debug "after JIRA transition_issue"
    end

    def processing_event event
      event.log self
    end

    def processing_status_changed_event card, prop_name
      @logger.info "Processing event: #{prop_name} changed for card ##{card}."
    end

    def processing_uninteresting_event id
      @logger.info "Processing event: uninteresting -- will be ignored. ID #{id}."
    end

    def application_stopped
      @logger.warn("Application stopped")
    end

    def fatal_mingle_error error
      response_body = escape_newline(error.response_body)
      @logger.fatal("Mingle #{error.status} error occurred while requesting for #{error.url}. The response body is #{response_body} ")
    end

    def card_not_found project, number
      @logger.error("Mingle card #{project}/##{number} could not be found.")
    end

    def issue_key_missing project, card_number
      @logger.info("Event ignored as there was no JIRA issue key in Mingle card #{project}/##{card_number}.")
    end

    def fatal_error(e)
      @logger.fatal "There has been a fatal error: #{e.message}. See exceptions.log for more details."
      @exceptions.fatal 'There has been a fatal error.', org.jruby.exceptions.RaiseException.new(e)
    end

    def log_exception(exception)
      exception.log self
    end

    def missing_config(section, entry)
      @logger.fatal("Configuration error occured: #{section}.#{entry} is missing.")
    end

    def unexpected_config(section, entry)
      @logger.fatal("Configuration error occured: #{section}.#{entry} is unexpected.")
    end

    def duplicate_config(section, entry)
      @logger.fatal("Configuration error occured: #{section}.#{entry} is defined in more than one place.")
    end

    def webclient_get_before url
      @logger.debug "before WebClient.get -- url: #{url}"
    end

    def webclient_get_after response
      @logger.debug "after WebClient.get -- status: #{response.status}, body: #{escape_newline(response.body)}"
    end

    def webclient_post_before url, params
      @logger.debug "before WebClient.post -- url: #{url}, params: #{params.inspect}"
    end

    def webclient_post_after response
      @logger.debug "after WebClient.post -- status: #{response.status}, body: #{escape_newline(response.body)}"
    end

    def bookmarking_a_new_project project
      @logger.info "Bookmarking project #{project} for the first time."
    end

    def another_instance_running
      @logger.fatal("Mingle-JIRA Connector not starting. There is another instance of the Connector running.")
    end

    private
    def log_into_file(file_name, logger)
      layout = org.apache.log4j.PatternLayout.new '%p %d{ISO8601} %m%n'
      appender = org.apache.log4j.FileAppender.new(layout, file_name)
      logger.addAppender(appender)
    end

    def escape_newline(str)
      str.to_s.gsub("\n", ";")
    end
  end
end

class Exception
  def log logger
    logger.fatal_error self
  end
end
