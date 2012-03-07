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

import static org.junit.Assert.*;
import org.junit.Test;
import java.util.*;
import static org.mockito.Mockito.*;

public class MappingTests {
    @Test public void convertsStringToMap() {
        assertEquals("value", Mapping.parse("key=>value").get("key").force());
    }

    @Test public void handlesMultipleValues() {
        Mapping map = Mapping.parse("key1=>value1,key2=>value2");
        assertEquals("value1", map.get("key1").force());
        assertEquals("value2", map.get("key2").force());
    }

    @Test public void ignoresSurroundingWhitespace() {
        Mapping map = Mapping.parse("key1=>value1, key2 => value2 ");
        assertEquals("value2", map.get("key2").force());
    }

    @Test public void comparesKeysWithoutRegardToCase() {
        assertEquals("value", Mapping.parse("kEy=>value").get("KeY").force());
    }

    @Test(expected=Maybe.NoValue.class) public void returnsNothingIfThereIsNoMappingForAKey() {
        Mapping.parse("a=>b").get("unmapped").force();
    }

    @Test public void isEmptyIfThereAreNoMappingsDefined() {
        assertTrue(Mapping.parse("").isEmpty());
    }

    @Test public void anEmptyMappingCanBeConstructed() {
        assertTrue(Mapping.empty().isEmpty());
    }

    @Test public void isCaseInsensitiveWhenInitializedWithAMap() {
        Mapping map = Mapping.fromMap(new HashMap<String, String>() {{
                    put("MUMBLE mumble", "newt");
                }});
        assertEquals("newt", map.get("mUmBlE MuMbLe").force());
    }

    @Test public void mappingsCanBeAdded() {
        Mapping map = Mapping.empty();
        map.add("from", "to");
        assertEquals("to", map.get("from").force());
    }

    @Test public void canIterateMappings() {
        Map original = new HashMap<String, String>() {{
                    put("key1", "value1");
                    put("key2", "value2");
            }};
        Mapping map = Mapping.fromMap(original);

        final Map received = new HashMap<String, String>();
        map.each(new Mapping.Receiver() {
                public void receive(String key, String value) {
                    received.put(key, value);
                }
            });

        assertEquals(original, received);
    }

    @Test public void preservesOriginalCaseWhenIterating() {
        Mapping map = Mapping.parse("KeY1=>ValUe1");

        final Map<String, String> received = new HashMap<String, String>();
        map.each(new Mapping.Receiver() {
                public void receive(String key, String value) {
                    received.put(key, value);
                }
            });

        assertEquals("ValUe1", received.get("KeY1"));
    }
}
