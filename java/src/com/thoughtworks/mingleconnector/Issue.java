// Copyright 2011 ThoughtWorks, Inc.
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you
// may not use this file except in compliance with the License. You may
// obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
// implied. See the License for the specific language governing
// permissions and limitations under the License.
// 
package com.thoughtworks.mingleconnector;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

public interface Issue {
    public String key();
    public String type();
    public String summary();
    public String description();
    public String url();
    public String project();
    public void mingleUrl(String url);
    public <T> Maybe<T> field(Field<T> field);

    public class Field<T> {
        private static final Map<String, Field> instances = new HashMap<String, Field>();
        public static Field<String> ASSIGNEE = new Field<String>("ASSIGNEE");
        public static Field<String> REPORTER = new Field<String>("REPORTER");
        public static Field<String> PROJECT = new Field<String>("PROJECT");
        public static Field<String> KEY = new Field<String>("KEY");
        public static Field<Date> CREATED = new Field<Date>("CREATED");
        public static Field<Date> DUE_DATE = new Field<Date>("DUE_DATE");
        public static Field<String> PRIORITY = new Field<String>("PRIORITY");

        private final String name;
        private Field(String name) {
            this.name = name;
            instances.put(name, this);
        }

        public Maybe<T> of(Issue issue) {
            return issue.field(this);
        }

        public String toString() { return name; }

        public static <T> Field<T> named(String name) {
            String canonicalName = name.toUpperCase().replace(' ', '_');
            if (!instances.containsKey(canonicalName)) {
                throw new RuntimeException("Unknown field: " + canonicalName);
            }
            return instances.get(canonicalName);
        }
    }
}
