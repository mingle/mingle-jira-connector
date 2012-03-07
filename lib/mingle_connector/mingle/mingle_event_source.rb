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
  class MingleEventSource
    def initialize mingle, section
      @mingle = mingle
      @status_properties = section[:status_properties]
      @project = section[:identifier]
    end

    def events
      @mingle.feed(@project).
        map(&method(:event_from))
    end

    class Event
      def initialize entry, change, dev_complete_status
        @entry, @change, @dev_complete_status = entry, change, dev_complete_status
      end

      def type() 'mingle' end

      def development_status
        @change.new_value
      end

      def development_complete?
        @change.new_value.downcase == @dev_complete_status.downcase
      end

      def mingle_card_number
        @entry.card_number
      end

      def project() @entry.project end

      def handled
        @entry.read
      end
      alias :could_not_be_handled :handled

      def log logger
        logger.processing_status_changed_event mingle_card_number, @change.property
      end
    end

    class UninterestingEvent
      def initialize(entry) @entry=entry end
      def type() 'uninteresting' end
      def handled() @entry.read end
      def log(logger) logger.processing_uninteresting_event(@entry.ident) end
    end

    private
    def event_from entry
      @status_properties.each do |name, value|
        change = entry.change_to(name) and return Event.new(entry, change, value)
      end
      return UninterestingEvent.new(entry)
    end
  end
end
