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
require 'fakefs/spec_helpers'
load_file 'mingle_connector'

include MingleConnector
describe ProcessLock do
  include FakeFS::SpecHelpers

  before do
    @file_path = '/tmp/fake_mingle_connector.pid'
    platform = mock
    platform.stub!(:pid_file_path).and_return @file_path
    @process_lock = ProcessLock.new platform
  end

  it "locked? should be true if there is a pid file" do
    File.open(@file_path, 'w').close
    @process_lock.locked?.should be_true
  end

  it "lock should create the pid file for the platform" do
    @process_lock.lock
    File.exist?(@file_path).should be_true
  end

  it "unlock should remove the pid file for the platform" do
    File.open(@file_path, 'w').close
    @process_lock.unlock
    File.exist?(@file_path).should be_false
  end
end
