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

import static com.thoughtworks.mingleconnector.TestSupport.*;

import java.util.*;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;

import org.junit.*;
import static org.junit.Assert.*;

public class ConfigTests {
    protected final Map values = new HashMap() {{
        put("Mingle server", "");
        put("Project mappings", "");
        put("Handover statuses", "");
        put("Mingle user", "");
        put("Mingle password", "");
    }};
    protected Config config() { return new Config(values); }

    @RunWith(value = Parameterized.class)
    public static class EachMandatoryEntry extends ConfigTests {
        @Parameters public static Collection<Object[]> data() {
            Object[][] data = new Object[][] {
                {"Mingle server"},
                {"Project mappings"},
                {"Handover statuses"},
                {"Mingle user"},
                {"Mingle password"}
            };
            return Arrays.asList(data);
        }

        @Test(expected=IllegalArgumentException.class) public void isMandatory() {
            values.remove(mandatoryKey);
            config();
        }

        private final String mandatoryKey;
        public EachMandatoryEntry(String mandatoryKey) {
            this.mandatoryKey = mandatoryKey;
        }
    }

    @RunWith(value = Parameterized.class)
    public static class EachMapping extends ConfigTests {
        @Parameters public static Collection<Object[]> data() {
            Object[][] data = new Object[][] {
                {
                    Config.Property.PROJECTS,
                    new GetMapping() {
                        public Mapping from(Config config) {
                            return config.projects();
                        }
                    }
                },
                {
                    Config.Property.HANDOVER_STATUSES,
                    new GetMapping() {
                        public Mapping from(Config config) {
                            return config.handoverStatuses();
                        }
                    }
                }
            };
            return Arrays.asList(data);
        }

        @Test public void isPopulatedFromAMapDefinition() {
            values.put(property.toString(),
                       "abcd=>1234, efgh=>5678");
            assertEquals("1234", getMapping.from(config()).get("abcd").force());
            assertEquals("5678", getMapping.from(config()).get("efgh").force());
        }

        final Config.Property property;
        final GetMapping getMapping;

        public EachMapping(Config.Property property,
                                       GetMapping getMapping) {
            this.property = property; this.getMapping = getMapping;
        }
    }

    @RunWith(value = Parameterized.class)
    public static class EachOptionalMapping extends EachMapping {
        @Parameters public static Collection<Object[]> data() {
            Object[][] data = new Object[][] {
                {
                    Config.Property.PRIORITIES,
                    new GetMapping() {
                        public Mapping from(Config config) {
                            return config.priorities();
                        }
                    }
                },
                {
                    Config.Property.PROPERTIES,
                    new GetMapping() {
                        public Mapping from(Config config) {
                            return config.properties();
                        }
                    }
                },
                {
                    Config.Property.TYPES,
                    new GetMapping() {
                        public Mapping from(Config config) {
                            return config.types();
                        }
                    }
                },
                {
                    Config.Property.INITIAL_CARD_VALUES,
                    new GetMapping() {
                        public Mapping from(Config config) {
                            return config.initialCardValues();
                        }
                    }
                }
            };
            return Arrays.asList(data);
        }

         @Test public void isOptional() {
            assertThat(property.toString(), containsString("optional"));
            values.remove(property.toString());
            assertTrue(getMapping.from(config()).isEmpty());
        }

        public EachOptionalMapping(Config.Property property,
                                       GetMapping getMapping) {
            super(property, getMapping);
        }
    }

    private interface GetMapping {
        Mapping from(Config config);
    }
}
