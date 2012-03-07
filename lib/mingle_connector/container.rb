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
  class Container
    def add name, klass=nil, &initializer
      add_initializer(name, klass, initializer)
    end

    def decorate name, klass=nil, &initializer
      add_initializer(name, klass, initializer) do |initializer|
        existing_init = find_initializer(name)
        lambda { initializer.call.decorating(existing_init.call) }
      end
    end
    
    def [] name
      find_initializer(name).call
    end

    class ObjectNotFoundError < StandardError
      def initialize(name) @name=name end
      def message() "No object named #{@name}." end
    end
    
    private
    def initializers() @initializers ||= {} end

    def find_initializer name
      initializers[name] or raise ObjectNotFoundError.new(name)
    end

    def add_initializer name, klass, initializer, &wrap
      initializer = initializer_from(klass, initializer)
      wrap and initializer = wrap.call(initializer)
      initializers[name] = memoize initializer
    end
    
    def memoize initializer
      value = nil
      lambda { value ||= initializer.call }
    end

    def initializer_from(klass, initializer)
      initializer ? lambda { initializer.call(self) } : lambda { klass.new }
    end
  end
end
