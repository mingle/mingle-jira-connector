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
load_file 'composite_event_source'

describe CompositeEventSource do
  it "returns the events from a single source" do
    source = struct(:events=>[Object.new])
    CompositeEventSource.new([source]).events.should == source.events
  end

  it "returns the events from two sources" do
    source1 = struct(:events=>[Object.new, Object.new])
    source2 = struct(:events=>[Object.new, Object.new])
    events = CompositeEventSource.new([source1, source2]).events
    events.should include(*source1.events)
    events.should include(*source2.events)
  end
end
