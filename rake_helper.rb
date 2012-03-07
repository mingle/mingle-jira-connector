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
MACRO_VERSION = '2.0.2'

PLATFORMS = {
  :linux=>{
    :extension=>'tar.gz',
    :name=>'linux',
  },
  :win32=>{
    :extension=>'zip',
    :name=>'win32',
  },
}

BUILD = {
  :listener_jar=>'tmp/build/mingle-listener.jar'
}

def macro_version_short() MACRO_VERSION end
def macro_version_long() macro_version_short + '-' + build_number end

def add_version_number root_dir
  Dir.glob("#{root_dir}/**/*").each do |file_path|
    data = IO.read file_path
    file = File.open(file_path,'w')
    data.gsub!('%VERSION_NUMBER%',MACRO_VERSION)
    file.write(data)
    file.close
  end
end
