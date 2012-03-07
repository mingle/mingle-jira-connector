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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Config {
    public enum Property {
        PROJECTS("Project mappings", true),
            HANDOVER_STATUSES("Handover statuses", true),
            TYPES("Type mappings", false),
            PROPERTIES("Property mappings", false),
            PRIORITIES("Priority mappings", false),
            INITIAL_CARD_VALUES("Initial card values", false),
            MINGLE("Mingle server", true), USER("Mingle user", true),
            PASSWORD("Mingle password", true);

        private final String name;
        private final boolean mandatory;
        private Property(String name, boolean mandatory) {
            this.name = name; this.mandatory = mandatory;
        }

        public String toString() {
            if (mandatory) return name;
            return name + " (optional)";
        }
        public boolean mandatory() { return mandatory; }

        public static String[] names() {
            List<String> names = new ArrayList<String>();
            for (Property property : values()) {
                names.add(property.toString());
            }
            return names.toArray(new String[0]);
        }
    }

    private final Map params;
    public Config(Map params) {
        this.params = params;
        validate();
    }

    public Mapping projects() { return getMapped(Property.PROJECTS); }
    public Mapping handoverStatuses() { return getMapped(Property.HANDOVER_STATUSES); }
    public Mapping types() { return getMapped(Property.TYPES); }
    public Mapping properties() { return getMapped(Property.PROPERTIES); }
    public Mapping priorities() { return getMapped(Property.PRIORITIES); }
    public Mapping initialCardValues() { return getMapped(Property.INITIAL_CARD_VALUES); }
    public String mingle() { return get(Property.MINGLE); }
    public String user() { return get(Property.USER); }
    public String password() { return get(Property.PASSWORD); }

    private boolean defined(Property property) { return params.containsKey(property.toString()); }
    private String get(Property property) { return (String) params.get(property.toString()); }
    private Mapping getMapped(Property property) {
        if (!defined(property)) return Mapping.empty();
        return Mapping.parse(get(property));
    }

    private void validate() {
        for (Property property : Property.values()) {
            if(!property.mandatory()) {
                continue;
            }
            if (!params.containsKey(property.toString()) || get(property) == null) {
                throw new IllegalArgumentException(errorMessage(property));
            }
        }
    }

    private String errorMessage(Property property) {
        return "ERROR - Mingle-JIRA Connector configuration is invalid. '" +
            property + "' parameter must be provided.";
    }
}
