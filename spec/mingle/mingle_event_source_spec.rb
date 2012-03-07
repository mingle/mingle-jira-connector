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
load_files 'mingle/mingle_event_source', 'mingle/feed'
include MingleConnector

describe MingleEventSource do
  def status_properties() @status_properties ||= {'Status'=>'Done'} end
  def project() @project ||= 'the-project' end
  def entries() (@entries ||= []).map { |entry| PropertyChange.new(entry, @card_number, project) } end
  def mingle() @mingle ||= StubMingle.new.with_feed(entries) end
  def source()
    @source ||= MingleEventSource.new(mingle, {:identifier=>project, :status_properties=>status_properties})
  end
  def events() source.events end

  it "returns the events from the Mingle feed" do
    @entries = [{'Status'=>'Ready'}, {'Status'=>'Done'}]
    events.should have(2).entries
  end

  it "returns events for bug and story status changes" do
    @status_properties = {'Story Status'=>'Done', 'Bug Status'=>'Done'}
    @entries = [{'Story Status'=>'Ready'}, {'Bug Status'=>'Done'}]
    events.should have(2).entries
  end

  it "converts feed entries into events" do
    @card_number = 54
    @entries = ['Status'=>'In Progress']
    events.first.mingle_card_number.should == 54
    events.first.development_status.should == 'In Progress'
  end

  it "returns uninteresting events for changes to other properties" do
    @entries = ['Owner'=>'Bob']
    events.first.type.should == 'uninteresting'
  end

  it "returns uninteresting events for non property-change entries" do
    @mingle = StubMingle.new.with_feed([NonPropertyChange.new])
    events.first.type.should == 'uninteresting'
  end

  it "extracts status changes from entries with multiple changes" do
    @entries = [{'Owner'=>'Bob', 'Status'=>'Done'}]
    events.first.development_status.should == 'Done'
  end

  it "only returns a single event if story and bug use the same status property" do
    @status_properties = {'Status'=>'Done'}
    @entries = ['Status'=>'In Progress']
    events.should have(1).event
  end

  it "provides events with their project" do
    @project = 'entries-project'
    @entries = ['Status'=>'In Progess']
    events.first.project.should == 'entries-project'
  end

  it "asks for the feed by project" do
    mingle.should_receive(:feed).with('the-project').and_return entries
    events
  end

  describe "development completeness" do
    context "single status property with default value" do
      before { @status_properties = {'Status'=>'Done'} }

      it "is development complete if the status is 'Done'" do
        @entries= ['Status'=>'Done']
        events.first.development_complete?.should be_true
      end

      it "isn't development complete if the status isn't 'Done'" do
        @entries= ['Status'=>'In Progess']
        events.first.development_complete?.should_not be_true
      end

      it "isn't sensitive to case in the matter of what is 'done'" do
        @entries= ['Status'=>'dOnE']
        events.first.development_complete?.should be_true
      end
    end

    context "single status property with different value" do
      before { @status_properties = {'Status'=>'Complete'} }

      it "is development complete if the status is configured value" do
        @entries= ['Status'=>'Complete']
        events.first.development_complete?.should be_true
      end

      it "isn't development complete if the status isn't configured value" do
        @entries= ['Status'=>'In Progess']
        events.first.development_complete?.should_not be_true
      end

      it "isn't sensitive to case in the value of the status" do
        @entries= ['Status'=>'cOmPlEtE']
        events.first.development_complete?.should be_true
      end
    end

    context "multiple status properties with different values" do
      before { @status_properties = {'Story Status'=>'Done', 'Bug Status'=>'Fixed'} }

      it "marks each as development complete" do
        entries = ['Story Status'=>'Done', 'Bug Status'=>'Fixed']
        events.each { |e| e.development_complete?.should be_true }
      end

      it "doesn't confuse the values" do
        entries = ['Story Status'=>'Fixed', 'Bug Status'=>'Done']
        events.each { |e| e.development_complete?.should_not be_true }
      end
    end
  end
end

describe MingleEventSource::Event do
  it "marks the entry as read when it is handled" do
    entry = mock('entry')
    entry.should_receive(:read)
    MingleEventSource::Event.new(entry, nil, nil).handled
  end

  it "has type 'mingle'" do
    MingleEventSource::Event.new(nil, nil, nil).type.should == 'mingle'
  end

  it "marks the entry as read if it cannot be handled" do
    entry = mock('entry')
    entry.should_receive(:read)
    MingleEventSource::Event.new(entry, nil, nil).could_not_be_handled
  end

  it "logs its number and property" do
    entry = struct(:card_number=>'56')
    change = struct(:property=>'Story Status')
    logger = mock('logger')
    logger.should_receive(:processing_status_changed_event).with('56', 'Story Status')
    MingleEventSource::Event.new(entry, change, nil).log(logger)
  end
end

describe MingleEventSource::UninterestingEvent do
  it "marks the entry as read when it is handled" do
    entry = mock('entry')
    entry.should_receive(:read)
    MingleEventSource::UninterestingEvent.new(entry).handled
  end

  it "has type 'mingle'" do
    MingleEventSource::UninterestingEvent.new(nil).type.should == 'uninteresting'
  end

  it "logs itself" do
    entry = struct(:ident=>'entry-id')
    logger = mock('logger')
    logger.should_receive(:processing_uninteresting_event).with('entry-id')
    MingleEventSource::UninterestingEvent.new(entry).log(logger)
  end
end

class NonPropertyChange
  def changes?(property) false end
  def change_to(property) nil end
end

class PropertyChange
  attr_reader :project, :card_number
  def initialize(changes, card_number, project)
    @changes, @card_number, @project = changes, card_number, project
  end
  def changes?(property) @changes.keys.include?(property) end
  def change_to(property)
    value = @changes[property]
    value and struct(:property=>property, :new_value=>value)
  end
end
