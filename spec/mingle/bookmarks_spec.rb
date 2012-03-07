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
load_files 'mingle/bookmarks'
include MingleConnector
require 'fakefs/spec_helpers'

describe FileSystemMultiProjectBookmarks do
  include FakeFS::SpecHelpers

  def bookmarks() FileSystemMultiProjectBookmarks.new(@logger || Void.new) end

  context "saves to disk" do
    before {bookmarks.mark_read(entry('http://1234', 'the-project'))}

    it "saves the entry id to disk" do
      File.exists?('bookmark').should be_true
    end

    it "includes the  ident in the file" do
      File.read('bookmark').should include "http://1234"
    end

    it "includes the project in the file" do
      File.read('bookmark').should include "the-project"
    end
  end

  context "the feed has been read before" do
    before do
      bookmarks.mark_read(entry('a-read', 'project-a'))
      bookmarks.mark_read(entry('b-read', 'project-b'))
    end

    it "says entry is read if the bookmark file contains its ident" do
      bookmarks.read?(entry('a-read', 'project-a')).should be_true
    end

    it "says entry is unread if the ident doesn't match what's in the bookmark file" do
      bookmarks.read?(entry('b-read', 'project-a')).should be_false
    end

    it "says entry is unread if the project doesn't match what's in the bookmark file" do
      bookmarks.read?(entry('a-read', 'project-b')).should be_false
    end
  end

  it "marks multiple projects as read" do
    bookmark = bookmarks
    bookmark.mark_read entry('a', 'project-a')
    bookmark.mark_read entry('b', 'project-b')

    bookmark.read?(entry 'a', 'project-a').should be_true
    bookmark.read?(entry 'b', 'project-b').should be_true
  end

  context "the feed hasn't been read before so there is no bookmark file" do
    it "says entry is read" do
      bookmarks.read?(entry('any', 'any-project')).should be_true
    end

    it "saves the entry as the bookmark" do
      bookmarks.read?(entry('any', 'any-project'))

      bookmarks.read?(entry('any', 'any-project')).should be_true
      bookmarks.read?(entry('another', 'any-project')).should be_false
    end
  end

  context "some other project has a bookmark" do
    before do
      bookmarks.read?(entry('another', 'different-project'))
    end

    it "says the project is read when it has no bookmark but other projects do" do
      bookmarks.read?(entry('any', 'new-project')).should be_true
    end

    it "bookmarks the entry when the project has no previous bookmark" do
      bookmarks.read?(entry('first', 'new-project')).should be_true
      bookmarks.read?(entry('next', 'new-project')).should be_false
    end

    it "tells the logger that this is a new project" do
      @logger = mock('logger')
      @logger.should_receive(:bookmarking_a_new_project).with('new-project')
      bookmarks.read?(entry('first', 'new-project'))
    end
  end

  it "doesn't read the file repeatedly" do
    File.should_receive(:open).once.and_return('the-project: the-bookmark')
    bookmark = bookmarks
    bookmark.read?(entry('1', 'the-project'))
    bookmark.read?(entry('2', 'the-project'))
  end

  def entry(id, project) struct(:ident=>id, :project=>project) end
end
