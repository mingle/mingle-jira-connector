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
require File.dirname(__FILE__)+'/config.rb'
require File.dirname(__FILE__)+'/web_client.rb'
require File.dirname(__FILE__)+'/jira.rb'
require File.dirname(__FILE__)+'/mingle/mingle.rb'

module MingleConnector
  class Application
    def initialize(event_source, logger, event_processor, environment)
      @event_source = event_source; @logger = logger
      @event_processor = event_processor; @environment = environment
    end

    def run
      begin
        begin
          @logger.application_started
          @environment.validate
          process_events
        ensure
          @logger.application_stopped
        end
      rescue JiraHostNotFoundError => e
        @logger.jira_host_not_found e
      rescue InvalidJiraCredentialsError => e
        @logger.invalid_jira_credentials e
      rescue HttpResponseError => e
        @logger.fatal_mingle_error e
      rescue InvalidJIRAField => e
        @logger.invalid_jira_field(e)
      rescue Exception => e
        @logger.log_exception e
      end
    end

    private
    def process_events
      events = @event_source.events
      events.each do |e|
        @event_processor.process e
      end
    end
  end
end
