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
require File.dirname(__FILE__) + '/spec_helper'
load_file 'mingle_connector'

include MingleConnector
describe LockingApplication do
  before do
    @logger = StubLogger.new
    @process_lock = StubProcessLock.new
    @app_mock = StubApplication.new
  end

  def locking_app
    @locking_app = LockingApplication.new(@process_lock, @logger)
    @locking_app.decorating @app_mock
  end

  it "does not start the application if there is a lock" do
    @process_lock.stub!(:locked?).and_return(true)
    @app_mock.should_not_receive(:run)
    locking_app.run
  end

  it "sets and unsets a lock before and after the application runs" do
    strict_order_mocks :process_lock, :app_mock
    @process_lock.stub!(:locked?).and_return(false)
    @process_lock.expect :lock
    @app_mock.expect :run
    @process_lock.expect :unlock
    locking_app.run
  end

  context "logging" do
    it "logs that another instance is running if there is a lock" do
      @process_lock.stub!(:locked?).and_return(true)
      @logger.should_receive :another_instance_running
      locking_app.run
    end
  end

  it "unlocks the locker even if the application throws an exception" do
    @process_lock.stub!(:locked?).and_return(false)
    @app_mock.stub!(:run).and_raise(Exception.new 'I will blow up')
    @process_lock.should_receive(:unlock)
    begin
      locking_app.run
    rescue Exception
    end
  end
end
