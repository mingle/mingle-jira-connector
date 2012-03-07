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
require 'forwardable'

module MingleConnector
  class FileConfigReader
    def read
      YamlConfigReader.new(load_file).read
    end

    private
    def load_file
      File.open('mingle-jira-connector-config.yml') { |f| f.read }
    end
  end

  class YamlConfigReader
    def initialize raw_string
      @data = YAML.load raw_string
    end

    def read
      @data
    end
  end

  class Config
    def initialize options
      @spec = options[:spec]
      @reader = options[:reader]
    end

    def validate
      errors = sections.map { |s| s.errors }.flatten
      errors.empty? or raise InvalidConfig.new errors
    end

    def section name
      entry = data[name.to_s] || {}
      Section.new entry, @spec[name], name
    end

    private
    def data
      @data ||= @reader.read
    end

    def sections
      @spec.keys.map(&method(:section))
    end

    class Section
      def initialize data, spec, name
        @data = data; @spec = spec; @name = name
      end

      def [] key
        entry = entry_for(key) or raise UnknownEntry.new(@name, key)
        entry.value
      end

      def errors
        entry_errors + unexpected
      end

      def responds_to key
        @name.to_s == key.to_s
      end

      def value
        self
      end

      private
      def entry_errors
        entries.map(&:errors).flatten
      end

      def unexpected
        @data.keys.find_all { |k| !entry_for(k) }.
          map { |k| Unexpected.new(@name, k) }
      end

      def entries
        @spec.map { |e| convert e }
      end

      def entry_for key
        entries.find { |e| e.responds_to key }
      end

      def convert e
        e.is_a? Array and return SectionArray.new(@name, @data, e.first)
        e[:spec] and return Section.new(@data[e[:name].to_s], e[:spec], e[:name])
        Entry.new(@name, e, @data)
      end

      class SectionArray
        extend Forwardable
        def_delegators :@sections, :first, :last, :map

        def self.match e
        end

        def initialize parent, data, spec
          @parent, @spec = parent, spec
          section_data = data[name] || data[the_alias] || []
          @sections = section_data.map { |d| Section.new(d, spec[:spec], name) }
        end

        def responds_to key
          name == key.to_s or the_alias == key.to_s
        end

        def value
          self
        end

        def errors()
          my_errors + my_sections_errors
        end

        private
        def name() @spec[:name].to_s end
        def the_alias() @spec[:alias].to_s end

        def my_errors
          @sections.empty? and return [Missing.new(@parent, name)]
          []
        end

        def my_sections_errors
          @sections.map(&:errors).flatten
        end
      end

      class Entry
        def initialize(section, spec, data) @section, @spec, @data = section, spec, data end

        def value
          raw = @data[name] || @data[the_alias] || default
          converter.call(raw)
        end

        def errors
          duplicate? and return [Duplicate.new(@section, name)]
          missing? and return [Missing.new(@section, name)]
          return []
        end

        def responds_to key
          name == key.to_s or the_alias == key.to_s
        end

        private
        def name
          @spec[:name].to_s
        end

        def default
          @spec[:default]
        end

        def the_alias
          @spec[:alias].to_s
        end

        def missing?
          !(@spec[:optional] || value)
        end

        def duplicate?() @data[name] and @data[the_alias] end

        def converter()
          @spec[:converter] or identity
        end

        def identity() lambda { |x| x } end
      end
    end

    class InvalidConfig < Exception
      def initialize errors
        @errors = errors
      end

      def log logger
        @errors.each { |error| error.log logger }
      end
    end

    class Missing
      def initialize section, entry
        @section = section
        @entry = entry
      end
      def log logger
        logger.missing_config(@section, @entry)
      end
    end

    class Unexpected
      def initialize section, entry
        @section, @entry = section, entry
      end
      def log logger
        logger.unexpected_config(@section, @entry)
      end
    end

    class Duplicate
      def initialize section, entry
        @section, @entry = section, entry
      end

      def log logger
        logger.duplicate_config(@section, @entry)
      end
    end

    class UnknownEntry < Exception
      def initialize(section, entry) @entry=entry; @section=section end
      def message() "Unknown config entry '#{@entry}' in section '#{@section}'." end
    end
  end
end
