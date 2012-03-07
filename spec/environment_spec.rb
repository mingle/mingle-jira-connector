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
load_files('environment')

describe Environment do
  it "should ask each element that is passed to it to validate itself" do
    arg_1 = mock
    arg_2 = mock
    arg_1.should_receive(:validate)
    arg_2.should_receive(:validate)

    environment = Environment.new arg_1, arg_2
    environment.validate
  end
end
