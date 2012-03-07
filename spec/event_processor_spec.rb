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
load_file 'event_processor'

include MingleConnector
describe EventProcessor do
  def event_processor
    @event_processor ||= EventProcessor.new(mingle, jira, logger)
  end
  def issue_key() @issue_key ||= '' end
  def mingle() @mingle ||= StubMingle.new(:issue_key=>issue_key) end
  def logger() @logger ||= StubLogger.new end
  def jira() @jira ||= StubJira.new end
  def a_url() 'http://api/v2/something.xml' end

  context "uninteresting events"  do
    before do
      @event = StubEvent.new('uninteresting')
    end

    it "event should be marked as handled" do
      @event.should_receive(:handled)
      event_processor.process @event
    end

    it "logs that the event is being processed" do
      logger.should_receive(:processing_event).with @event
      event_processor.process @event
    end
  end

  context "mingle events" do
    def event() @event ||= mingle_event_with(:development_status=>@development_status) end

    it "marks the mingle event as handled" do
      event.should_receive :handled
      event_processor.process event
    end

    describe "updating development status" do
      it "updates development_status property on the jira issue with issue key" do
        @issue_key = 'MITP-66'
        jira.should_receive(:update_development_status).with("MITP-66", anything)
        event_processor.process event
      end

      it "updates development_status property on the jira issue with status" do
        @development_status = 'New'
        jira.should_receive(:update_development_status).with(anything, "New")
        event_processor.process event
      end
    end

    describe "marking dev complete" do
      context "card is done" do
        before { @development_status = 'Done' }

        it "marks the issue as development complete" do
          @issue_key = 'the-issue-key'
          jira.should_receive(:handback).with('the-issue-key')
          event_processor.process event
        end

        context "transition is invalid" do
          before do
            @error = InvalidJIRATransition.new(nil,nil)
            jira.stub!(:handback).and_raise(@error)
          end

          it "still marks the event as handled" do
            event.should_receive(:handled)
            event_processor.process(event)
          end

          it "logs the problem" do
            logger.should_receive(:invalid_transition).with @error
            event_processor.process(event)
          end
        end
      end

      it "doesn't mark the issue as development complete if the card is not 'Done'" do
        @development_status = 'In Progress'
        jira.should_not_receive(:handback)
        event_processor.process event
      end
    end

    describe "interactions with mingle" do
      it "asks mingle for the card using the events card number" do
        mingle.should_receive(:get_card).with(45, anything)
        event_processor.process mingle_event_with :card_number=>45
      end

      it "asks mingle for the card using the events project name" do
        mingle.should_receive(:get_card).with(anything, 'the-events-project')
        event_processor.process mingle_event_with(:project=>'the-events-project')
      end
   end

    it "tells logger that is processing event" do
      logger.should_receive(:processing_event).with event
      event_processor.process event
    end

    context "card cannot be found" do
      before { @mingle = NoCardFoundMingle.new }

      it "marks the event as unhandleable" do
        event.should_receive(:could_not_be_handled)
        event_processor.process event
      end

      it "logs what happened" do
        logger.should_receive(:card_not_found).with('the-project', 45)
        event_processor.process(mingle_event_with :project=>'the-project', :card_number=>45)
      end
    end

    context "the event is for a card not links to JIRA" do
      before { mingle.card = CardWithNoIssueKey.new }

      it "logs what happened" do
        mingle_event = mingle_event_with :project=>'the-project', :card_number => 45
        logger.should_receive(:issue_key_missing).with('the-project', 45)
        event_processor.process mingle_event
      end

      it "marks the event as handled" do
        event.should_receive(:handled)
        event_processor.process event
      end

      class CardWithNoIssueKey
        def issue_key()  end
      end
    end

    context "issue does not exist" do
      before do
        @error = IssueDoesNotExistError.new 'issue'
        jira.stub!(:update_development_status).and_raise(@error)
      end

      it "still marks the event as handled" do
        event.should_receive(:handled)
        event_processor.process(event)
      end

      it "logs the error" do
        logger.should_receive(:issue_missing).with @error
        event_processor.process(event)
      end

      it "adds a comment to the Mingle card" do
        event = mingle_event_with :card_number=>31, :project=>'the-project'
        mingle.should_receive(:add_comment).
          with(event.mingle_card_number, event.project,
               'The issue from which this card was created has been deleted in JIRA.')
        event_processor.process(event)
      end
    end
  end
end

def mingle_event() mingle_event_with({}) end
def mingle_event_with(props)
  StubMingleEvent.new(props)
end

class StubMingleEvent
  def initialize(props) @props=props end
  def type() 'mingle' end
  def mingle_card_number() @props[:card_number] end
  def handled() end
  def could_not_be_handled() end
  def development_status() @props[:development_status] or '' end
  def development_complete?() development_status == 'Done' end
  def project() @props[:project] end
end

class NoCardFoundMingle
  def get_card(number, project) end
end

class StubJira
  def update_development_status(card_number, status) end
  def handback(issue) end
end

class StubEvent
  def initialize(type) @type=type end
  def type() @type end
  def handled() end
end
