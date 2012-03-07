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
describe Platform do
  before do
    @os_name = ENV_JAVA['os.name']
  end

  it "should return the correct file location for windows" do
    ENV_JAVA['os.name'] = "Windows"
    file_path = File.expand_path(File.dirname(__FILE__) + '/../mingle_connector.pid')
    Platform.new.pid_file_path.should == file_path
  end

  it "it should return the correct file location for Mac" do
    ENV_JAVA['os.name'] = "Mac OS X"
    file_path = "/tmp/mingle_connector.pid"
    Platform.new.pid_file_path.should == file_path
  end

  it "it should return the correct file location for Linux" do
    ENV_JAVA['os.name'] = "Linux"
    file_path = "/tmp/mingle_connector.pid"
    Platform.new.pid_file_path.should == file_path
  end

  after do
    ENV_JAVA['os.name'] = @os_name
  end
end
