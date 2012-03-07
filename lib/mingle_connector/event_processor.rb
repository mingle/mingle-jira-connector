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
require File.dirname(__FILE__)+'/jira'

module MingleConnector
  class EventProcessor
    def initialize mingle, jira, logger
      @mingle = mingle
      @jira = jira
      @logger = logger
    end

    def process(e)
      @logger.processing_event e
      event_types = {
        "mingle" => lambda { process_mingle_event e },
        "uninteresting" => lambda { e.handled }
      }
      event_types[e.type].call
    end

    private
    def process_mingle_event e
      card = @mingle.get_card(e.mingle_card_number, e.project)
      unless card
        @logger.card_not_found(e.project, e.mingle_card_number)
        e.could_not_be_handled
        return
      end
      issue_key = card.issue_key
      begin
        if issue_key
          @jira.update_development_status(issue_key, e.development_status)
          e.development_complete? and @jira.handback(issue_key)
        else
          @logger.issue_key_missing(e.project, e.mingle_card_number)
        end
      rescue InvalidJIRATransition => ex
        @logger.invalid_transition(ex)
      rescue IssueDoesNotExistError => ex
        @logger.issue_missing ex
        @mingle.add_comment(e.mingle_card_number, e.project, 'The issue from which this card was created has been deleted in JIRA.')
      end
      e.handled
    end
  end
end
