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
$:.unshift File.dirname(__FILE__) + '/../../../vendor/gems/activesupport-2.3.5/lib/'
require 'active_support'

module MingleConnector
  class Mingle
    def initialize(web_client, config, feed_reader)
      @web_client = web_client; @config = config
      @jira_issue_key_prop = config[:jira_issue_key_property]
      @feed_reader = feed_reader
    end

    def get_card number, project
      begin
        resp = @web_client.get url_for(card(number), project)
        Card.new(resp.body, @jira_issue_key_prop)
      rescue HttpNotFoundError
        nil
      end
    end

    def add_comment card, project, comment
      @web_client.post(url_for(comment_on(card), project),
                       {'comment[content]'=>comment})
    end

    def feed project
      @feed_reader.read url_for event_feed, project
    end

    def validate
      @web_client.get(base_url+'/projects.xml')
    end

    private
    def card number
      "cards/#{number}.xml"
    end

    def comment_on number
      "cards/#{number}/comments.xml"
    end

    def event_feed
      'feeds/events.xml'
    end

    def base_url
      "#{@config[:baseurl]}/api/v2"
    end

    def url_for suffix, project
      "#{base_url}/projects/#{project}/#{suffix}"
    end
  end

  class Card
    def initialize(xml, issue_prop)
      @details = Hash.from_xml(xml)['card']
      @issue_prop = issue_prop
    end

    def issue_key
      property = @details['properties'].
        find_all { |prop| prop['name'] }.
        find { |prop| prop['name'].downcase==@issue_prop.downcase }
      property && property['value']
    end
  end
end
