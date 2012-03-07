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
require 'yaml'

module MingleConnector
  class FileSystemMultiProjectBookmarks
    FILE = 'bookmark'

    def initialize logger
      @logger = logger
      @yaml = ( File.exists?(FILE) && YAML::load(File.open(FILE)) ) || Hash.new
    end

    def mark_read entry
      @yaml[entry.project] = entry.ident
      File.open(FILE, 'w') { |f| YAML.dump @yaml, f }
    end

    def read? entry
      @yaml[entry.project] or initialize_project(entry)
      @yaml[entry.project] == entry.ident
    end

    private
    def initialize_project entry
      @logger.bookmarking_a_new_project(entry.project)
      mark_read(entry)
    end
  end
end
