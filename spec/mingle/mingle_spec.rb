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
require File.dirname(__FILE__)+'/../spec_helper'
load_files 'mingle/mingle', 'web_client'

include MingleConnector
describe Mingle do
  before do
    @web = StubWebClient.new
  end

  def config()
    {:project=>@project, :baseurl=>@baseurl,
      :jira_issue_key_property=>@jira_issue_key_prop, :story_type => @story_type_prop}
  end

  def mingle()
    Mingle.new @web, config, @feed_reader
  end

  describe 'validate' do
    it "should return true if it can fetch the projects" do
      @web.should_receive(:get).
         with(%r{/api/v2/projects.xml}).and_return(response :body => '')
      mingle.validate.should be_true
    end
  end

  describe 'get card' do
    it "should return a card" do
      @jira_issue_key_prop = 'Jira issue'
      body = <<-XML
<card>
  <properties type="array">
    <property>
      <name>Jira issue</name>
      <value>MITP-14</value>
    </property>
  </properties>
</card>
XML
      @web.stub!(:get).and_return(response :body => body)
      card = mingle.get_card 2, nil
      card.issue_key.should == 'MITP-14'
    end

    context "card cannot be found" do
      before { @web = NotFoundResponseWebClient.new }
      it "returns nil" do
        mingle.get_card(nil, nil).should == nil
      end
    end

    context "other HTTP errors" do
      before { @web = ErrorResponseWebClient.new }
      it "propogates them" do
        lambda { mingle.get_card(nil, nil) }.should raise_error HttpResponseError
      end
    end

    describe "requesting" do
      def minimal_response()
        response :body=>'<card><description></description></card>'
      end

      it 'passes a single get request' do
        @web.should_receive(:get).once.and_return minimal_response
        mingle.get_card nil, nil
      end

      it 'structure of card url right' do
        @web.should_receive(:get).
          with(%r{/api/v2/projects/.*/cards/.*xml}).
          and_return minimal_response
        mingle.get_card nil, nil
      end

      it 'puts the server details into the URL' do
        @baseurl = 'http://localhost:8080'
        @web.should_receive(:get).with(%r{http://localhost:8080/}).
          and_return minimal_response
        mingle.get_card nil, nil
      end

      it 'puts the project name into the URL' do
        @web.should_receive(:get).with(%r{/projects/different-project/}).
          and_return minimal_response
        mingle.get_card nil, 'different-project'
      end

      it 'puts the card number into the URL' do
        @web.should_receive(:get).with(%r{/cards/2.xml}).and_return minimal_response
        mingle.get_card 2, nil
      end
    end
  end

  describe 'adding comments' do
    context "on failures" do
      before { @web = ErrorResponseWebClient.new }
      it "propogates the error" do
        lambda { mingle.add_comment(nil, nil, nil) }.should raise_error HttpResponseError
      end
    end

    context 'requesting' do
      it 'puts a single request' do
        @web.should_receive(:post).once.and_return response(:status => 200)
        mingle.add_comment(nil, nil, nil)
      end

      it "forms uses the base url for the card's comment URL" do
        @baseurl = 'http://foo:8080'
        @web.should_receive(:post).
          with(%r{http://foo:8080/api/v2/}, anything).and_return response(:status => 200)
        mingle.add_comment(nil, nil, nil)
      end

      it "puts the request to the card's comment URL" do
        @baseurl = 'http://foo:8080'
        @web.should_receive(:post).
          with(%r{.+/cards/2/comments.xml}, anything).and_return response(:status => 200)
        mingle.add_comment(2, nil, nil)
      end

      it "uses the passed project to form the URL" do
         @web.should_receive(:post).with(%r{.*/a-project/}, anything)
        mingle.add_comment(nil, 'a-project', nil)
      end

      it "puts the comment as a parameter" do
        params = {'comment[content]'=>'here is the comment'}
        @web.should_receive(:post).with(anything, params).and_return response(:status => 200)
        mingle.add_comment(nil, nil, 'here is the comment')
      end
    end
  end

  describe 'feed' do
    before { @feed_reader = mock('feed_reader') }

    it "returns the feed from the reader" do
      @feed_reader.stub!(:read).and_return 'the-feed'
      mingle.feed(nil).should == 'the-feed'
    end

    it "reads the feed from the feed url" do
      @feed_reader.should_receive(:read).with(%r{.*/a-project/feeds/events.xml})
      mingle.feed 'a-project'
    end
  end
end

describe Card do
  it "knows the issue key" do
    xml = <<-XML
<card>
  <properties type="array">
    <property>
      <name>Jira issue</name>
      <value>MITP-14</value>
    </property>
  </properties>
</card>
XML
    card = Card.new xml, 'Jira issue'
    card.issue_key.should == 'MITP-14'
  end

  it "ignores issue key case" do
    xml = <<-XML
<card>
  <properties type="array">
    <property>
      <name>Jira issue</name>
      <value>MITP-14</value>
    </property>
  </properties>
</card>
XML
    card = Card.new xml, 'JIRA issue'
    card.issue_key.should == 'MITP-14'
  end

  it "returns nil if the property is missing" do
    xml = <<-XML
<card>
  <number type="integer">5</number>
  <properties type="array">
    <property>
    </property>
  </properties>
</card>
XML
    card = Card.new xml, 'Jira issue'
    card.issue_key.should be_nil
  end

  it "returns nil if the property has no value" do
    xml = <<-XML
<card>
  <number type="integer">5</number>
  <properties type="array">
    <property>
      <name>Jira issue</name>
      <value></value>
    </property>
  </properties>
</card>
XML
    card = Card.new xml, 'Jira issue'
    card.issue_key.should be_nil
  end
end

def response(options={})
  WebClient::Response.new(options[:status] || 200,
                          options[:body] || '',
                          options[:headers] || {})
end

class ErrorResponseWebClient
  def get(url) raise_error end
  def post(url, params) raise_error end
  private
  def raise_error() raise HttpResponseError.new(nil, nil, nil) end
end

class NotFoundResponseWebClient
  def get(url) raise_error end
  private
  def raise_error() raise HttpNotFoundError.new(nil, nil, nil) end
end
