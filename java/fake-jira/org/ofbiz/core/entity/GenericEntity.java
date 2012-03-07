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
package org.ofbiz.core.entity;

public class GenericEntity {
    private final String field;
    private final String newstring;

    public GenericEntity(String field, String newstring) {
        this.field = field; this.newstring = newstring;
    }

    public String getString(String name) {
        if(name.equals("field")) return field;
        if(name.equals("newstring")) return newstring;
        return null;
    }
}
