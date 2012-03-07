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
%w{mingle/mingle logging mingle/mingle_event_source composite_event_source
   jira web_client application config event_processor container
   environment mingle/feed_reader mingle/feed mingle/bookmarks}.
  each { |f| require "mingle_connector/#{f}" }

module MingleConnector
  class Factory
    def initialize(config_reader, config_spec, container)
      @config_reader=config_reader; @config_spec=config_spec; @c=container
    end

    def application
      common
      mingle
      jira
      event_source
      event_processor
      environment
      process_lock
      @c.add(:app) { Application.new(@c[:event_source], @c[:logger], @c[:event_processor], @c[:environment])}
      @c.decorate(:app) { LockingApplication.new(@c[:process_lock], @c[:logger]) }

      @c[:app]
    end

    private
    def process_lock
      @c.add(:process_lock) { ProcessLock.new(Platform.new) }
    end

    def common
      @c.add(:config) { Config.new :reader=>@config_reader, :spec=>@config_spec }
      @c.add(:logger) { Logging.new(@c[:config].section(:logging)) }
    end

    def event_source
      @c.add(:mingle_event_source) { CompositeEventSource.new(mingle_event_sources) }
      @c.add(:event_source) { @c[:mingle_event_source] }
    end

    def mingle_event_sources
      @c[:config].section(:mingle)[:projects].map do |project|
        MingleEventSource.new(@c[:mingle], project)
      end
    end

    def mingle
      @c.add(:web_client, WebClient)
      @c.decorate(:web_client) { AuthenticatingWebClient.new(@c[:config].section(:mingle)[:user],
                                                             @c[:config].section(:mingle)[:password]) }
      @c.decorate(:web_client) { LoggingWebClient.new(@c[:logger]) }
      @c.decorate(:web_client, ResponseValidatingWebClient)

      @c.add(:feed) { XmlFeed.new.with_web(@c[:web_client]) }
      @c.add(:feed_reader) { FeedReader.new(@c[:feed],
                                            FileSystemMultiProjectBookmarks.new(@c[:logger])) }
      @c.add(:mingle) { Mingle.new(@c[:web_client], @c[:config].section(:mingle),
                                   @c[:feed_reader]) }
    end

    def jira
      @c.add(:jira_api) { JiraAPI.new(@c[:config].section(:jira)[:baseurl]) }
      @c.decorate(:jira_api) { LoggingJiraAPI.new(@c[:logger]) }
      @c.decorate(:jira_api, ResponseCheckingJiraApi)

      @c.add(:jira) { Jira.new(@c[:jira_api],
                               @c[:logger],
                               @c[:config].section(:jira)) }
    end

    def event_processor
      @c.add(:event_processor) { EventProcessor.new(@c[:mingle], @c[:jira], @c[:logger]) }
    end

    def environment
      @c.add(:environment) {Environment.new(@c[:config], @c[:mingle], @c[:jira])}
    end
  end
end

