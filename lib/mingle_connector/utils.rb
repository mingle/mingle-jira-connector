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
module MingleConnector
  module Decorator
    attr_reader :wrapped
    def decorating(wrapped)
      @wrapped = wrapped
      self
    end
  end

  module Utils
    def self.load_gems *gems
      gems.each { |g| $:.unshift File.dirname(__FILE__) + "/../../vendor/gems/#{g}/lib/" }
    end

    def turn_off_logging_for *loggers
      loggers.each do |name|
        logger = org.apache.log4j.Logger.get_logger name
        logger.set_level(org.apache.log4j.Level.to_level('OFF'))
      end
    end
  end
end
