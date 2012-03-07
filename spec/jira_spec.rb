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
load_file 'jira'

include MingleConnector
describe Jira do
  before { @api = StubJiraAPI.new }
  before { @logger = StubLogger.new }
  def jira
    @jira ||=  Jira.new @api, @logger, {:user=>'name', :password=>'password',
                                        :mingle_dev_status_field=>@development_status,
                                        :transitions=>@transitions||Void.new}
  end

  describe "validate" do
    it "asks jira to login" do
      @api.should_receive(:login)
      jira.validate
    end
  end

  describe "login" do
    it "logs in when updating development status" do
      @development_status = 'something-not-nil'
      @api.should_receive(:login).with 'name', 'password'
      jira.update_development_status nil, nil
    end

    it "logs in when marking an issue as development complete" do
      @api.should_receive(:login).with 'name', 'password'
      jira.handback ''
    end

    it "only ever logs in once" do
      @api.should_receive(:login).once
      jira.handback ''
      jira.handback ''
    end
  end

  describe "handback to jira" do
    it "transitions the issue" do
      @api.should_receive(:transition_issue).with('the-key', anything)
      jira.handback('the-key')
    end

    it "applies the configured transition" do
      @transitions = {'ISS'=>'project trans'}
      @api.should_receive(:transition_issue).with(anything, 'project trans')
      jira.handback('ISS-1')
    end

    it "logs the update" do
      @transitions = {'ISS'=>'project trans'}
      @logger.should_receive(:jira_issue_transitioned).with('ISS-1', 'project trans')
      jira.handback('ISS-1')
    end

    it "throws exception if no transition configured for project" do
      @transitions = {}
      lambda { jira.handback('UNKNOWN-1') }.should raise_exception Jira::UnknownProject
    end
  end

  describe "update development status" do
    context "development status field is defined" do
      before { @development_status = 'status-id' }

      it "updates the issue with the status" do
        @api.should_receive(:update_issue).with('ABC-123', anything, 'the-status')
        jira.update_development_status('ABC-123' , 'the-status')
      end

      it "updates the appropriate field prepending prefix" do
        @api.should_receive(:update_issue).with(anything, 'customfield_status-id', anything)
        jira.update_development_status(nil, nil)
      end

      it "logs the update" do
        @logger.should_receive(:jira_issue_updated).with'ABC-123', 'status-id', 'the-status'
        jira.update_development_status 'ABC-123' , 'the-status'
      end
    end

    context "development status field is not defined" do
      before { @development_status = nil }

      it "doesn't update the issue" do
        @api.should_not_receive(:update_issue)
        jira.update_development_status(nil, nil)
      end

      it "logs what happened" do
        @logger.should_receive(:development_status_not_defined).with 'the-key'
        jira.update_development_status('the-key', nil)
      end
    end
  end
end

describe Jira::UnknownProject do
  it "gets logged" do
    logger = mock('logger')
    logger.should_receive(:unknown_jira_project).with('PROJ')
    Jira::UnknownProject.new('PROJ').log(logger)
  end
end

{
  :update_issue=>['the-key', 'the-field', 'the-value'],
  :transition_issue=>['the-key', 'the-transition'],
  :login=>['the-name', 'the-password']
}.each do |method, args|
  shared_examples_for "delegates #{method}" do
    it "passes on the parameters" do
      wrapped.should_receive(method).with(*args).and_return(Void.new)
      api.send(method, *args)
    end

    it "passes back the return value" do
      the_return = Void.new
      wrapped.stub!(method).and_return(the_return)
      api.send(method, *args).should equal the_return
    end
  end
end

shared_examples_for 'delegates everything' do
  it_should_behave_like 'delegates update_issue'
  it_should_behave_like 'delegates transition_issue'
  it_should_behave_like 'delegates login'
end

describe "Jira decorators" do
  def wrapped() @wrapped ||= StubJiraAPI.new end

  describe LoggingJiraAPI do
    def logger() @logger end
    def api() LoggingJiraAPI.new(logger).decorating wrapped end

    describe 'delegation' do
      before { @logger = StubLogger.new }
      it_should_behave_like 'delegates everything'
    end

    describe 'logging' do
      before { strict_order_mocks  :logger, :wrapped }

      it "logs before and after login" do
        logger.expect.jira_login_before 'name'
        wrapped.expect.login anything, anything
        logger.expect.jira_login_after

        api.login 'name', 'password'
      end

      it "logs before and after update_issue" do
        logger.expect.jira_update_issue_before 'issue', 'field', 'value'
        wrapped.expect.update_issue anything, anything, anything
        logger.expect.jira_update_issue_after

        api.update_issue 'issue', 'field', 'value'
      end

      it "logs before and after transition_issue" do
        logger.expect.jira_transition_issue_before 'issue', 'transition'
        wrapped.expect.transition_issue anything, anything
        logger.expect.jira_transition_issue_after

        api.transition_issue 'issue', 'transition'
      end
    end
  end

  describe ResponseCheckingJiraApi do
    def api() ResponseCheckingJiraApi.new.decorating(wrapped) end

    it_should_behave_like 'delegates everything'

    it "doesn't raise an exception if the response contains the field" do
      wrapped.stub!(:update_issue).and_return(response_with_fields(['a-field']))
      lambda { api.update_issue('an-issue', 'a-field', 'a-value') }.
        should_not raise_error InvalidJIRAField
    end

    it "raises an exception if the response doesn't contain the field" do
      wrapped.stub!(:update_issue).and_return(response_with_fields([]))
      lambda { api.update_issue('an-issue', 'a-field', 'a-value') }.
        should raise_error(InvalidJIRAField) { |e| e.field.should == 'a-field' }
    end

    def response_with_fields(fields)
      struct(:customFieldValues=>fields.collect { |f| struct(:customfieldId=>f) })
    end
  end
end

class StubJiraAPI
  def login(user, password) end
  def update_issue(issue, field, value) end
  def transition_issue(issue, transition) end
end
