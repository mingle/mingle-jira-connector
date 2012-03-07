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
load_files 'mingle/feed_reader', 'mingle/feed'
include MingleConnector

describe FeedReader do
  def pages() @pages end
  def feed() @feed ||= StubFeed.new(pages) end
  def bookmark() @bookmark ||= InMemoryBookmark.new(@bookmarked_item) end
  def reader() FeedReader.new(feed, bookmark) end

  it "returns the feed's entries in order" do
    @pages = [page_with('6', '5'), page_with('4', '3'), page_with('2', '1')]
    reader.read(nil).to_a.should == ['1', '2', '3', '4', '5', '6']
  end

  it "passes the url onto the feed" do
    feed.should_receive(:pages).with('the-url').and_return([])
    reader.read('the-url')
  end

  it "bookmarks entries when they are read" do
    @pages = [page_with('1')]
    entries = reader.read(nil)
    entries.first.read
    bookmark.read?("1").should be_true
  end

  it "uses the bookmark to determine where to start reading" do
    @bookmarked_item = "2"
    @pages = [page_with('3', '2', '1')]
    entries = reader.read(nil)
    entries.should have(1).entries
    entries.to_a.first.should == "3"
  end

  it "doesn't ask for any more pages after it finds a read entry" do
    second_page = page_with('x')
    @pages = [page_with('6', '5', '4'), second_page]
    @bookmarked_item = '5'
    second_page.should_not_receive(:entries)
    reader.read(nil)
  end
end

def page_with(*entries) struct(:entries=>entries) end

class StubFeed
  def initialize(pages) @pages=pages end
  def pages(url) @pages end
end

class InMemoryBookmark
  def initialize(entry) @entry = entry end

  def mark_read(entry)
    @entry = entry
  end
  def read?(entry)
    @entry == entry
  end
end
