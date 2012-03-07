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

import java.util.HashMap;
import java.util.Map;

public class Mingle {
    private final API api;
    private final String server;

    public Mingle(API api, String server) {
        this.api = api;
        this.server = server;
    }

    public Project project(String id) {
        return new Project(api, server, id);
    }

    public static class Project {
        private final API api;
        private final String server;
        private final String id;

        public Project(API api, String server, String id) {
            this.id = id;
            this.server = server;
            this.api = api;
        }

        public Card addCard(String type, String name, String description) {
            return new Card(type, name, description);
        }

        public class Card {
            private String type;
            private String name;
            private String description;
            private final Map<Object, Object> properties = new HashMap<Object, Object>();
            private String url;

            public Card(String type, String name, String description) {
                this.type = type;
                this.name = name;
                this.description = description;
            }

            public void property(String name, String value) {
                properties.put(name, value);
            }

            public String url() {
                return url;
            }

            public void save() {
                url = api.createCard(server, id, type, name, description, properties);
            }
        }
    }

    public interface API {
        String createCard(String server, String project, String type, String name,
                          String description, Map properties);
    }
}
