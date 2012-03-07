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
require File.dirname(__FILE__) + '/../spec_helper'
require File.dirname(__FILE__) + '/../shared/jira_server'
load_file 'jira'
include MingleConnector

describe JiraAPI do
  describe "network problems" do
    context "port is wrong or host is down" do
      before { @api = JiraAPI.new 'http://localhost:9999' }

      it "throws exception" do
        lambda{ @api.login(nil, nil) }.should raise_error JiraHostNotFoundError
      end

      it "passes the location to the exception" do
        begin
          @api.login(nil, nil)
        rescue JiraHostNotFoundError => e
          e.location.should == 'http://localhost:9999'
        end
      end
    end

    context "can't find host" do
      before { @api = JiraAPI.new 'http://doesnotexist' }

      it "throws exception" do
        lambda{ @api.login(nil, nil)}.should raise_error JiraHostNotFoundError
      end

      it "passes the location to the exception" do
        begin
          @api.login(nil, nil)
        rescue JiraHostNotFoundError => e
          e.location.should == 'http://doesnotexist'
        end
      end
    end
  end

  context "running server" do
    before do
      @server = JiraHttpServer.new 3090
      @server.start
      @api = JiraAPI.new 'http://localhost:3090'
    end
    after { @server.stop }

    describe "log in" do
      it "passes the username and password to jira" do
        @api.login 'bob', 'secret'
        @server.credentials.
          should =={:username=>'bob', :password=>'secret'}
      end

      it "reuses the authentication token on future requests" do
        @api.login nil, nil
        @api.update_issue nil, nil, nil
        @server.token_received.should ==@server.token
      end

      it "throws exception if credentials are wrong" do
        @server.error_on_auth = true
        lambda {@api.login '', ''}.should raise_error InvalidJiraCredentialsError
      end

      it "passes on SOAP faults" do
        @server.soap_error_on_auth = true
        lambda {@api.login '', ''}.should raise_error SOAP::FaultError
      end
    end

    context "logged in" do
      before { @api.login nil, nil }

      describe "update issue" do
        it "passes the parameters to the server" do
          @api.update_issue 'the-key', 'the-field', 'value'
          @server.issue_with_key('the-key')['the-field'].should =='value'
        end

        it "raises an exception when issue cannot be found" do
          lambda { @api.update_issue 'missing', nil, nil }.
            should raise_error(IssueDoesNotExistError) {|e| e.issue_key.should == 'missing'}
        end

        it "propogates other SOAP errors" do
          @server.error_on_update_issue = true
          lambda { @api.update_issue nil, nil, nil }.should raise_error SOAP::FaultError
        end
      end

      describe "transition issue" do
        it "causes a transition on the server" do
          @server.add_issue :key=>'QCONN-key', :type=>'Bug'
          @api.transition_issue 'QCONN-key', 'Development Complete'
          @server.issue_with_key('QCONN-key').should have_status 'Resolved'
        end

        it "is not sensitive to the case of the transition name" do
          @server.add_issue :key=>'QCONN-key', :type=>'Bug'
          @api.transition_issue 'QCONN-key', 'dEvElOpMeNt CoMpLeTe'
          @server.issue_with_key('QCONN-key').should have_status 'Resolved'
        end

        it "raises an exception if the transition doesn't exist" do
          lambda { @api.transition_issue 'the-key', 'nonsense' }.
            should raise_error(InvalidJIRATransition) { |e|
              e.message.should match 'nonsense'
              e.message.should match 'the-key'
            }
        end

        it "raises an exception if the issue doesn't exist" do
          lambda { @api.transition_issue 'QCONN-missing', 'Development Complete' }.
            should raise_error(IssueDoesNotExistError) {|e| e.issue_key.should == 'QCONN-missing'}
        end

        it "propogates other SOAP errors" do
          @server.error_on_update_issue = true
          lambda { @api.transition_issue 'QCONN-1', 'Development Complete' }.
            should raise_error SOAP::FaultError
        end
      end
    end
  end
end
