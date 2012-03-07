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
load_files 'config'
include MingleConnector
require 'fakefs/spec_helpers'

describe FileConfigReader do
  include FakeFS::SpecHelpers
  it "parses a valid config file" do
    yaml =   <<-YAML
  section:
    entry: value
YAML
    File.open('mingle-jira-connector-config.yml', 'w') { |f| f.write(yaml) }
    FileConfigReader.new.read['section']['entry'].should =='value'
  end
end
