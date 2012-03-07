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

public class Mapping {
    public static interface Receiver {
        void receive(String from, String to);
    }

    private final Map<String, String> entries = new HashMap<String, String>();
    private Mapping() { }

    public static Mapping empty() {
        return new Mapping();
    }

    public static Mapping fromMap(Map<String, String> map) {
        Mapping mapping = new Mapping();
        for (Map.Entry<String, String> entry : map.entrySet()) {
            mapping.add(entry.getKey(), entry.getValue());
        }
        return mapping;
    }

    public static Mapping parse(String string) {
        Mapping mapping = new Mapping();
        String[] list = string.trim().split(" *, *");
        for(String entry : list) {
            String[] pair  = entry.split(" *=> *");
            if (pair.length < 2) continue;
            mapping.add(pair[0], pair[1]);
        }
        return mapping;
    }

    public boolean isEmpty() {
        return entries.isEmpty();
    }

    public void add(String from, String to) {
        entries.put(from, to);
    }

    public Maybe<String> get(String from) {
        for (Map.Entry<String, String> entry : entries.entrySet()) {
            if(entry.getKey().equalsIgnoreCase(from)) {
                return Maybe.definitely(entry.getValue());
            }
        }
        return Maybe.nothing();
    }

    public void each(Receiver receiver) {
        for (Map.Entry<String, String> entry : entries.entrySet()) {
            receiver.receive(entry.getKey(), entry.getValue());
        }
    }
}
