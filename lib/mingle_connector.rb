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
$:.unshift File.expand_path(File.dirname(__FILE__))
require 'java'
require 'mingle_connector/factory'
require 'mingle_connector/container'

module MingleConnector
  def self.run(config_reader=FileConfigReader.new)
    Factory.new(config_reader, self.config, Container.new).application.run
  end

  def self.config
    {
      :mingle=>[{:name=>:baseurl},
                {:name=>:user},
                {:name=>:password},
                [{:name=>:projects, :alias=>:project,
                   :spec=>[{:name=>:identifier},
                           {:name=>:status_properties, :default=>{'Status'=>'Done'}}]}],
                {:name=> :jira_issue_key_property, :default=>'JIRA issue'},
               ],
      :logging=>[{:name=>:filename, :default=>'mingle-jira-connector.log'},
                 {:name=>:level, :default=>'WARN'},
                 {:name => :exceptions_filename, :default=>'exceptions.log'}],
      :jira=>[{:name=>:baseurl},
              {:name=>:user},
              {:name=>:password},
              {:name=>:mingle_dev_status_field, :optional=>true},
              {:name=>:transitions}]}
  end

  class LockingApplication
    include Decorator
    def initialize process_locker, logger
      @process_locker = process_locker
      @logger = logger
    end

    def run
      unless @process_locker.locked?
        @process_locker.lock
        begin
          @wrapped.run
        ensure
          @process_locker.unlock
        end
      else
        @logger.another_instance_running
      end
    end
  end

  class Platform
    def pid_file_path
      return "/tmp/mingle_connector.pid" if os_name.include? "Mac"
      return "/tmp/mingle_connector.pid" if os_name.include? "Linux"
      return  windows_filename if os_name.include? "Windows"
    end

    private
    def os_name
      ENV_JAVA["os.name"]
    end

    def windows_filename
      File.expand_path(File.dirname(__FILE__) + '/../mingle_connector.pid')
    end
  end

  class ProcessLock
    def initialize platform
      @platform = platform
    end

    def locked?
      File.exist? @platform.pid_file_path
    end

    def lock
      File.open(@platform.pid_file_path, "w").close
    end

    def unlock
      File.delete(@platform.pid_file_path)
    end
  end
end
