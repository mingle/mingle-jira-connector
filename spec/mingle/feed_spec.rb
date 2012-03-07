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
load_file 'mingle/feed'
include MingleConnector

class InMemoryFeed
  include Feed
  def initialize(pages) @pages=pages end
  def parse content
    (@pages[content] || Object.new).extend(Feed::Page)
  end
end

describe Feed do
  def pages() @pages ||= {} end
  def web() @web ||= StubWebClient.from_string(@content) end
  def feed() @feed ||= InMemoryFeed.new(pages).with_web(web) end

  it "gets the content from the url" do
    web.should_receive(:get).with('the-url').and_return(struct(:body=>''))
    feed.page_at('the-url')
  end

  it "parses the content" do
    @content = 'the-content'
    @pages = {'the-content'=>'the-page'}
    feed.page_at(nil).should == 'the-page'
  end

  it "gives pages a way to fetch the next page" do
    page = mock('page')
    feed.stub!(:parse).and_return(page)
    page.should_receive(:with_fetcher).with(feed)
    feed.page_at(nil)
  end

  it "enumerates over the pages" do
    @web = CannedWebClient.new({:page1_url=>:page1_content, :page2_url=>:page2_content})
    page1 = page(:entries=>'first', :next=>:page2_url)
    page2 = page(:entries=>'second', :next=>nil)
    @pages = {:page1_content=>page1, :page2_content=>page2}
    feed.pages(:page1_url).map(&:entries).should == ['first', 'second']
  end

  it "adds the url to invalid feed errors" do
    @feed = InvalidFeed.new
    begin
      feed.pages('the-url')
    rescue Feed::Invalid => e
      e.message.should include('the-url')
    end
  end
end

class InvalidFeed
  include Feed
  def initialize() @web=StubWebClient.new end
  def parse(content) raise Invalid end
end

def page(opts)
  struct(:entries=>opts[:entries], :next_page_link=>opts[:next]).extend(Feed::Page)
end

describe Feed::Page do
  def fetcher() @fetcher ||= stub('fetcher') end
  def the_page()
    page(:next=>@next_page).with_fetcher(fetcher)
  end

  context "there is another page" do
    before { @next_page = 'the-next-page-link' }

    it "gets the page from the fetcher" do
      fetcher.should_receive(:page_at).with(@next_page)
      the_page.next
    end

    it "returns the fetched page" do
      fetcher.stub(:page_at).and_return('the-next-page')
      the_page.next.should == 'the-next-page'
    end
  end

  context "there are no more pages" do
    before { @next_page = nil }

    it "doesn't try to fetch another page" do
      fetcher.should_not_receive(:page_at)
      the_page.next
    end

    it "returns nothing" do
      the_page.next.should be_nil
    end
  end
end

describe Feed::Page::Entry do
  def entry
    struct({:changes=>@changes||[@change]}).extend(Feed::Page::Entry)
  end

  context "a single change which changes the property" do
    before { @change = does_change }

    it "returns the change" do
      entry.change_to('foo').should == @change
    end
  end

  context "a single change which doesn't change the property" do
    before { @change = doesnt_change }

    it "returns no changes" do
      entry.change_to('foo').should be_nil
    end
  end

  context "multiple changes with only one that changes the property" do
    before { @changes = [doesnt_change, does_change] }

    it "returns the change" do
      entry.change_to("foo").should == @changes.last
    end
  end

  def does_change() struct({:changes? => true}) end
  def doesnt_change() struct({:changes? => false}) end
end

describe Feed::Page::Entry::Change do
  def change() struct(:property=>@property).extend(Feed::Page::Entry::Change) end

  it "changes when the property is the same" do
    @property = 'foo'
    change.changes?('foo').should be_true
  end

  it "doesn't change when the property is different" do
    @property = 'bar'
    change.changes?('foo').should_not be_true
  end

  it "doesn't change when the property is the same but not in case" do
    @property = 'foo'
    change.changes?('Foo').should_not be_true
  end
end

describe XmlFeed do
  def entry() @entry end
  def xml() @xml ||= custom_atom_feed(entry) end
  def page() XmlFeed.new.parse(xml) end
  def entries() page.entries end

  context "malformed feed" do
    before { @xml = '<not-a-feed/>' }
    it "raises an error" do
      lambda { page }.should raise_error Feed::Invalid
    end
  end

  context "this is the earliest page in the feed" do
    before { @xml = "<feed></feed>" }

    it "has no next page" do
      page.next_page_link.should be_nil
    end
  end

  context "there are earlier pages" do
    before { @xml = "<feed><link rel='next' href='the-link'/></feed>" }

    it "has a link to the next page" do
      page.next_page_link.should == 'the-link'
    end
  end

  context "feed with a single entry" do
    before { @xml = single_atom_feed }

    it "gets an event from atom feed" do
      entries.should have(1).entry
    end

    it "gets the new value from the atom feed" do
      entries.first.changes.first.new_value.should == "Ready for QA"
    end

    it "has the project in the entry" do
      entries.first.project.should == "mingle_jira_connector"
    end
  end

  context "feed with two entries" do
    before { @xml = multi_atom_feed }

    it "gets two entries" do
      entries.should have(2).entries
    end

    it "get the new value from the atom feed" do
      entries.first.changes.first.new_value.should == "Done"
      entries.last.changes.first.new_value.should == "Ready for QA"
    end

    it "gets the card numbers from the feed" do
      entries.first.card_number.should == 736
      entries.last.card_number.should == 28
    end

    it "gets the entry's ident from the feed" do
      entries.first.ident.should == "https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/events/index/374908"
      entries.last.ident.should == "https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/events/index/15432"
    end
  end

  context "there are no entries in the feed" do
    before { @xml = empty_atom_feed }

    it "gets no entries from the feed" do
      entries.should be_empty
    end
  end

  context "entry with multiple changes" do
    it "has the details of each change" do
      @entry = entry_with_changes <<-CHANGES
        <change type="property-change">
          <property_definition url="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/property_definitions/885.xml">
            <name>Priority</name>
          </property_definition>
          <new_value>High</name>
        </change>
        <change type="property-change">
          <property_definition url="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/property_definitions/885.xml">
            <name>Status</name>
          </property_definition>
          <new_value>Ready</name>
        </change>
CHANGES
      entries.first.changes.first.property.should == 'Priority'
      entries.first.changes.first.new_value.should == 'High'
      entries.first.changes.last.property.should == 'Status'
      entries.first.changes.last.new_value.should == 'Ready'
    end
  end

  describe "non property-change entries" do
    it "reports non-card entries as having no changes" do
      @entry = entry_with_change_types('page-creation')
      entries.first.changes.should be_empty
    end

    it "reports card entries that are not property changes as having no changes" do
      @entry = entry_with_change_types('card-deletion')
      entries.first.changes.should be_empty
    end

    it "doesn't ignore property changes when there are other changes as well" do
      @entry = entry_with_change_types('description-change', 'property-change')
      entries.should_not be_empty
      entries.first.changes.should have(1).change
    end
  end
end

def single_atom_feed
  custom_atom_feed <<-ENTRY
  <entry>
    <id>https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/events/index/374908</id>
    <title>Task #736 Get system access for Gerv changed</title>
    <updated>2011-01-31T16:43:06Z</updated>
    <author>
      <name>Benjamin Butler-Cole</name>
      <email>bbutler@thoughtworks.com</email>
      <uri>https://mingle.thoughtworks-studios.com/api/v2/users/273.xml</uri>
    </author>
    <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/cards/736.xml" rel="http://www.thoughtworks-studios.com/ns/mingle#event-source" type="application/vnd.mingle+xml" title="Task #736"/>
    <link href="https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/cards/736" rel="http://www.thoughtworks-studios.com/ns/mingle#event-source" type="text/html" title="Task #736"/>
    <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/cards/736.xml?version=4" rel="http://www.thoughtworks-studios.com/ns/mingle#version" type="application/vnd.mingle+xml" title="Task #736 (v4)"/>
    <link href="https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/cards/736?version=4" rel="http://www.thoughtworks-studios.com/ns/mingle#version" type="text/html" title="Task #736 (v4)"/>
    <category term="card" scheme="http://www.thoughtworks-studios.com/ns/mingle#categories"/>
    <category term="property-change" scheme="http://www.thoughtworks-studios.com/ns/mingle#categories"/>
    <content type="application/vnd.mingle+xml">
      <changes xmlns="http://www.thoughtworks-studios.com/ns/mingle">
        <change type="property-change">
          <property_definition url="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/property_definitions/885.xml">
            <name>Status</name>
            <position nil="true"></position>
            <data_type>string</data_type>
            <is_numeric type="boolean">false</is_numeric>
          </property_definition>
          <old_value>In Dev</old_value>
          <new_value>Ready for QA</new_value>
        </change>
      </changes>
    </content>
  </entry>
ENTRY
end

def custom_atom_feed entries
  <<-FEED
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xmlns:mingle="http://www.thoughtworks-studios.com/ns/mingle">
  <title>Mingle Events: Studios Technical Solutions</title>
  <id>https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/feeds/events.xml</id>
  <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/feeds/events.xml" rel="current"/>
  <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/feeds/events.xml?page=331" rel="self"/>
  <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/feeds/events.xml?page=330" rel="next"/>
  <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/feeds/events.xml?page=332" rel="previous"/>
  <updated>2011-01-31T16:43:06Z</updated>
  #{entries}
</feed>
FEED
end

def multi_atom_feed
  custom_atom_feed <<-ENTRIES
  <entry>
    <id>https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/events/index/374908</id>
    <title>Task #736 Get system access for Gerv changed</title>
    <updated>2011-01-31T16:43:06Z</updated>
    <author>
      <name>Benjamin Butler-Cole</name>
      <email>bbutler@thoughtworks.com</email>
      <uri>https://mingle.thoughtworks-studios.com/api/v2/users/273.xml</uri>
    </author>
    <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/cards/736.xml" rel="http://www.thoughtworks-studios.com/ns/mingle#event-source" type="application/vnd.mingle+xml" title="Task #736"/>
    <link href="https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/cards/736" rel="http://www.thoughtworks-studios.com/ns/mingle#event-source" type="text/html" title="Task #736"/>
    <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/cards/736.xml?version=4" rel="http://www.thoughtworks-studios.com/ns/mingle#version" type="application/vnd.mingle+xml" title="Task #736 (v4)"/>
    <link href="https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/cards/736?version=4" rel="http://www.thoughtworks-studios.com/ns/mingle#version" type="text/html" title="Task #736 (v4)"/>
    <category term="card" scheme="http://www.thoughtworks-studios.com/ns/mingle#categories"/>
    <category term="property-change" scheme="http://www.thoughtworks-studios.com/ns/mingle#categories"/>
    <content type="application/vnd.mingle+xml">
      <changes xmlns="http://www.thoughtworks-studios.com/ns/mingle">
        <change type="property-change">
          <property_definition url="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/property_definitions/885.xml">
            <name>Status</name>
            <position nil="true"></position>
            <data_type>string</data_type>
            <is_numeric type="boolean">false</is_numeric>
          </property_definition>
          <old_value>In Dev</old_value>
          <new_value>Done</new_value>
        </change>
      </changes>
    </content>
  </entry>
  <entry>
    <id>https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/events/index/15432</id>
    <title>Task #28 Get system access for Gerv changed</title>
    <updated>2011-01-31T16:43:06Z</updated>
    <author>
      <name>Benjamin Butler-Cole</name>
      <email>bbutler@thoughtworks.com</email>
      <uri>https://mingle.thoughtworks-studios.com/api/v2/users/273.xml</uri>
    </author>
    <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/cards/28.xml" rel="http://www.thoughtworks-studios.com/ns/mingle#event-source" type="application/vnd.mingle+xml" title="Task #28"/>
    <link href="https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/cards/28" rel="http://www.thoughtworks-studios.com/ns/mingle#event-source" type="text/html" title="Task #28"/>
    <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/cards/28.xml?version=4" rel="http://www.thoughtworks-studios.com/ns/mingle#version" type="application/vnd.mingle+xml" title="Task #28 (v4)"/>
    <link href="https://mingle.thoughtworks-studios.com/projects/mingle_jira_connector/cards/28?version=4" rel="http://www.thoughtworks-studios.com/ns/mingle#version" type="text/html" title="Task #28 (v4)"/>
    <category term="card" scheme="http://www.thoughtworks-studios.com/ns/mingle#categories"/>
    <category term="property-change" scheme="http://www.thoughtworks-studios.com/ns/mingle#categories"/>
    <content type="application/vnd.mingle+xml">
      <changes xmlns="http://www.thoughtworks-studios.com/ns/mingle">
        <change type="property-change">
          <property_definition url="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/property_definitions/885.xml">
            <name>Status</name>
            <position nil="true"></position>
            <data_type>string</data_type>
            <is_numeric type="boolean">false</is_numeric>
          </property_definition>
          <old_value>In Dev</old_value>
          <new_value>Ready for QA</new_value>
        </change>
      </changes>
    </content>
  </entry>
ENTRIES
end

def empty_atom_feed
  custom_atom_feed ''
end

def entry_with_change_types *changes
  <<-ENTRY
<entry>
  #{changes.map { |c| "<change type='#{c}'/>" }.join}
</entry>
ENTRY
end

def entry_with_changes changes
  <<-ENTRY
  <entry>
    <link href="https://mingle.thoughtworks-studios.com/api/v2/projects/mingle_jira_connector/cards/736.xml" rel="http://www.thoughtworks-studios.com/ns/mingle#event-source" type="application/vnd.mingle+xml" title="Task #736"/>
    <category term="card" scheme="http://www.thoughtworks-studios.com/ns/mingle#categories"/>
    <category term="property-change" scheme="http://www.thoughtworks-studios.com/ns/mingle#categories"/>
    <content type="application/vnd.mingle+xml">
      <changes xmlns="http://www.thoughtworks-studios.com/ns/mingle">
        #{changes}
      </changes>
    </content>
  </entry>
ENTRY
end
