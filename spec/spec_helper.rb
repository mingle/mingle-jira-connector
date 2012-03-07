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
require 'rubygems'
require 'hardmock'

Spec::Runner.configure do |configuration|
  include Hardmock
  configuration.after(:each) { verify_mocks }
end

# Hardmock allows us to make cross-mock ordering expectations
def strict_order_mocks(*mocks)
  include Hardmock
  create_mocks *mocks
end
alias :strict_order_mock :strict_order_mocks

def load_files(*files)
  base_dir = File.dirname(__FILE__) + '/../lib/'
  files.each do |f|
    if (f == 'mingle_connector' || f == 'mingle_connector.rb')
      require base_dir + f
    else
      require base_dir + 'mingle_connector/' + f
    end
  end
end
alias :load_file :load_files

class StubMingle
  attr_writer :card

  def initialize opts={}
    @issue_key = opts[:issue_key]
  end

  def with_feed feed
    @feed = feed
    self
  end

  def with_project project
    @project = project
    self
  end

  def get_card card_number, project
    @card or StubCard.new @issue_key
  end

  def card_with_issue_key issue_key
  end

  def add_comment issue_key, project, comment
  end

  def feed(project) @feed end
end

class StubCard
  attr_reader :issue_key
  def initialize(issue_key) @issue_key=issue_key end
end

class StubLogger
  def method_missing(meth_id, *args, &block) end
end

def raised_exception(msg=nil)
  begin
    raise Exception.new msg
  rescue Exception => e
    error = e
  end
end

class StubLog4jLogger
  def addAppender(appender) end
end

class StubJiraTool
  def logger=(logger) end
  def login(user,password) end
end

class HashConfigReader
  def initialize(data) @data=data end
  def read() @data end
end

class StubWebClient
  def self.from_string(body) StubWebClient.new(struct(:body=>body)) end
  def initialize(response=struct(:body=>nil)) @response=response end
  def get(url) @response end
  def post(url, params) @response end
end

class CannedWebClient
  def initialize(content) @content=content end
  def get(url) struct(:body=>@content[url]) end
end

class StubProcessLock
  def lock() end

  def unlock() end
end

class StubApplication
  def run() end
end

require 'ostruct'
def struct(options) OpenStruct.new(options) end

def void() Void.new end
class Void
  def method_missing(name, *args)
    Void.new
  end
end
