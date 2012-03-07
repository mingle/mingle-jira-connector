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
$:.unshift File.dirname(__FILE__) + '/../../../vendor/gems/hpricot-0.8.2-java/lib/'
require 'hpricot'

module MingleConnector
  module Feed
    class Invalid < StandardError
      attr_accessor :url
      def message
        "There was an invalid feed at: #{url}"
      end
    end

    def page_at url
      parse(@web.get(url).body).with_fetcher(self)
    rescue Invalid => e
      e.url = url
      raise
    end

    def pages url
      PageEnumerator.new(page_at(url))
    end

    def with_web(web) @web = web; self end

    module Page
      def next
        if url = next_page_link
          @fetcher.page_at(url)
        end
      end

      def with_fetcher fetcher
        @fetcher = fetcher
        self
      end

      module Entry
        def change_to property
          changes.find { |c| c.changes?(property) }
        end

        module Change
          def changes? a_property
            property == a_property
          end
        end
      end
    end

    private
    class PageEnumerator
      include Enumerable
      def initialize(first_page) @page = first_page end
      def each
        while @page
          yield @page
          @page = @page.next
        end
      end
    end
  end

  class XmlFeed
    include Feed
    def parse content
      xml = Hpricot(content)
      xml.at('feed') or raise Invalid
      XmlPage.new(xml)
    end

    class XmlPage
      include Feed::Page
      def initialize xml
        @xml = xml
      end

      def next_page_link
        link = @xml.at('link[@rel="next"]') and link['href']
      end

      def entries
        @xml.search('entry').map &XmlEntry.method(:new)
      end

      private
      class XmlEntry
        include Feed::Page::Entry
        def initialize(xml) @xml = xml end

        def ident
          @xml.at('id').inner_text
        end

        def card_number
          card_url.split('/').last.gsub('.xml', '').to_i
        end

        def project
          card_url.split('/')[-3]
        end

        def changes
          @xml.search('change[@type=property-change]').map &XmlChange.method(:new)
        end

        private
        def card_url
          card_link = @xml.at("link[@rel='http://www.thoughtworks-studios.com/ns/mingle#event-source'][@type='application/vnd.mingle+xml']")
          card_link['href']
        end

        class XmlChange
          include Feed::Page::Entry::Change
          def initialize xml
            @xml = xml
          end

          def property
            value_of(@xml.at('property_definition/name'))
          end

          def new_value
            value_of(@xml.at('new_value'))
          end

          private
          def value_of element
            element.inner_text.strip
          end
        end
      end
    end
  end
end
