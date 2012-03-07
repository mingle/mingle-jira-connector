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
module Enumerable
  def lazy_map(&func) LazyMapEnumerable.new(self, func) end
  def lazy_flatten() LazyFlattenEnumerable.new(self) end

  class LazyFlattenEnumerable
    include Enumerable
    def initialize(wrapped) @wrapped=wrapped end

    def each
      @wrapped.each { |xs| xs.each { |x| yield x} }
    end
  end

  class LazyMapEnumerable
    include Enumerable
    def initialize wrapped, func
      @wrapped, @func = wrapped, func
    end

    def each
      @wrapped.each { |x| yield @func.call(x) }
    end
  end
end

module MingleConnector
  class FeedReader
    def initialize feed, bookmarks
      @feed, @bookmarks = feed, bookmarks
    end

    def read(feed_url)
      @feed.pages(feed_url).
        lazy_map(&:entries).
        lazy_flatten.
        lazy_map { |entry| entry.extend(StatefulEntry).with_state(@bookmarks) }.
        take_while(&:unread?).
        reverse_each
    end

    module StatefulEntry
      def with_state(state) @state = state; self end

      def read
        @state.mark_read(self)
      end

      def unread?
        !@state.read?(self)
      end
    end
  end
end
