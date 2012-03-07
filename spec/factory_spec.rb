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
load_files('mingle_connector', 'factory', 'application', 'container')
include MingleConnector

describe Factory do
  def container() @container ||= Container.new end
  def config() @config ||= {'mingle'=>{'projects'=>[]}} end
  def factory() Factory.new(HashConfigReader.new(config), MingleConnector::config, container) end

  it "creates the application" do
    factory.application.should be_instance_of LockingApplication
  end

  describe "decoration of application" do
    before { @container = DecorationCapturingContainer.new }
    before { @container.stub!(:capture) }

    it "decorates it with LockingApplication" do
      container.should_receive(:capture).
        with(:app, an_instance_of(LockingApplication))
      factory.application
    end
  end

  describe "decoration of JiraAPI" do
    before { @container = DecorationCapturingContainer.new }
    before { @container.stub!(:capture) }

    it "decorates it with LoggingJiraAPI" do
      container.should_receive(:capture).
        with(:jira_api, an_instance_of(LoggingJiraAPI))
      factory.application
    end

    it "decorates it with ResponseCheckingJiraApi" do
      container.should_receive(:capture).
        with(:jira_api, an_instance_of(ResponseCheckingJiraApi))
      factory.application
    end

    it "puts the logging before the response checking so that failures get logged" do
      container.should_receive(:capture).
        with(:jira_api, an_instance_of(LoggingJiraAPI)).ordered
      container.should_receive(:capture).
        with(:jira_api, an_instance_of(ResponseCheckingJiraApi)).ordered
      factory.application
    end
  end

  describe "decoration of WebClient" do
    before { @container = DecorationCapturingContainer.new }
    before { @container.stub!(:capture) }

    it "decorates it with LoggingWebClient" do
      container.should_receive(:capture).
        with(:web_client, an_instance_of(LoggingWebClient))
      factory.application
    end

    it "decorates it with AuthenticatingWebClient" do
      container.should_receive(:capture).
        with(:web_client, an_instance_of(AuthenticatingWebClient))
      factory.application
    end

    it "decorates it with ResponseValidatingWebClient" do
      container.should_receive(:capture).
        with(:web_client, an_instance_of(ResponseValidatingWebClient))
      factory.application
    end

    it "puts the authentication before the logging because it changes the api" do
      container.should_receive(:capture).
        with(:web_client, an_instance_of(AuthenticatingWebClient)).ordered
      container.should_receive(:capture).
        with(:web_client, an_instance_of(LoggingWebClient)).ordered
      factory.application
    end

    it "puts the authentication before the response checking because it changes the api" do
      container.should_receive(:capture).
        with(:web_client, an_instance_of(AuthenticatingWebClient)).ordered
      container.should_receive(:capture).
        with(:web_client, an_instance_of(ResponseValidatingWebClient)).ordered
      factory.application
    end

    it "puts the logging before the response checking so that failures get logged" do
      container.should_receive(:capture).
        with(:web_client, an_instance_of(LoggingWebClient)).ordered
      container.should_receive(:capture).
        with(:web_client, an_instance_of(ResponseValidatingWebClient)).ordered
      factory.application
    end
  end

  describe "creation of mingle" do
    it "Feed is created with the web" do
      feed = mock('feed')
      feed.should_receive(:with_web).with(duck_type(:get))
      XmlFeed.stub!(:new).and_return(feed)
      factory.application
    end
  end

  describe "event sources" do
    it "sources events from each mingle project" do
      @config = {
        'mingle'=>{
          'projects'=>[{'identifier'=>'1'}, {'identifier'=>'2'}, {'identifier'=>'3'}]
        }
      }
      @config['mingle']['projects'].each do |p|
        MingleEventSource.should_receive(:new).with(anything,
                                                    config_with_identifier(p['identifier']))
      end
      factory.application
    end
  end
end

class DecorationCapturingContainer < Container
  def decorate name, klass=nil, &initializer
    if klass
      capture(name, klass.new)
    else
      capture(name, initializer.call)
    end
  end
end

def config_with_identifier expected
  MatchConfigWithIdentifier.new expected
end

class MatchConfigWithIdentifier
  def initialize(expected_identifier)
    @expected = expected_identifier
  end

  def ==(actual)
    actual['identifier'] == @expected
  end

  def description
    "Config with identifier #{@expected}"
  end
end
