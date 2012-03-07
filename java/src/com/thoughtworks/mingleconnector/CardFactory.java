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

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.ArrayList;
import java.util.List;

public class CardFactory {
    private final Mapping typeMap;
    private final Mapping propertyMap;
    private final ProjectMap projectMap;
    private final Logger logger;
    private final List<PropertySetter> properties = new ArrayList<PropertySetter>();

    public CardFactory(Mapping typeMap, Mapping propertyMap, ProjectMap projectMap,
                       Mapping initialCardValueMap, Mapping priorityMap, Logger logger) {
        this.typeMap = typeMap;
        this.propertyMap = propertyMap;
        this.projectMap = projectMap;
        this.logger = logger;

        propertyMap.add("Key", "JIRA issue");

        addPropertyMapping("Project", SIMPLE);
        addPropertyMapping("Key", SIMPLE);
        addPropertyMapping("Assignee", SIMPLE);
        addPropertyMapping("Reporter", SIMPLE);
        addPropertyMapping("Created", DATE);
        addPropertyMapping("Due Date", DATE);
        addPropertyMapping("Priority", translation(priorityMap));

        initialCardValueMap.each(new Mapping.Receiver() {
                public void receive(String from, String to) {
                    properties.add(new InitialCardValue(from, to));
                }
            });
    }

    public Mingle.Project.Card createCard(Issue issue) {
        return new SingleUseFactory(issue).create();
    }

    private class SingleUseFactory {
        private final Issue issue;
        public SingleUseFactory(Issue issue) {
            this.issue = issue;
        }

        public Mingle.Project.Card create() {
            Mingle.Project.Card card = project().addCard(type(), name(), description());
            addProperties(card);
            return card;
        }

        private Mingle.Project project() {
            return projectMap.get(issue.project());
        }

        private String type() {
            return typeMap.get(issue.type()).force(issue.type());
        }

        private String name() {
            return issue.summary();
        }

        private String description() {
            // Don't put a full stop after the url. There is a Mingle bug
            // which causes this to be rendered incorrectly.
            return "This card was created from an issue in JIRA: "+issue.url()+
                "\n\n" +
                issue.description() + "\n";
        }

        private String jiraIssue() {
            return issue.key();
        }

        private void addProperties(Mingle.Project.Card card) {
            for (PropertySetter setter : properties) {
                setter.add(issue, card);
            }
        }
    }

    private void addPropertyMapping(final String field, final Function converter) {
        propertyMap.get(field).ifValue(new Action<String>() {
                public void call(String propertyName) {
                    properties.add(new PropertyMapping(field, propertyName, converter));
                }
            });
    }

    private static final Function<String, Maybe<String>> SIMPLE =
        new Function<String, Maybe<String>>() {
        public Maybe<String> call(String value) { return Maybe.definitely(value); }
    };
    private static final Function<Date, Maybe<String>> DATE = new Function<Date, Maybe<String>>() {
        public Maybe<String> call(Date date) {
            return Maybe.definitely(new SimpleDateFormat("dd MMM yyyy").format(date));
        }
    };
    private Function<String, Maybe<String>> translation(final Mapping priorityMap) {
        return new Function<String, Maybe<String>>() {
            public Maybe<String> call(String value) {
                return priorityMap.get(value);
            }
        };
    }

    private interface PropertySetter {
        void add(Issue issue, Mingle.Project.Card card);
    }

    private static class InitialCardValue implements PropertySetter {
        private final String name, value;
        public InitialCardValue(String name, String value) {
            this.name = name; this.value = value;
        }

        public void add(Issue issue, Mingle.Project.Card card) {
            card.property(name, value);
        }
    }

    private class PropertyMapping<T> implements PropertySetter {
        private final String field, property;
        private final Function<T, Maybe<String>> conversion;
        public PropertyMapping(String field, String property,
                               Function<T, Maybe<String>> conversion) {
            this.field = field; this.property = property; this.conversion = conversion;
        }

        public void add(Issue issue, final Mingle.Project.Card card) {
            field().of(issue).ifValue(new Action<T>() {
                    public void call(T raw) {
                        convert(raw).ifValue(setProperty(card),
                                             logUnmappable(raw));
                    }
                });
        }

        private Issue.Field<T> field() {
            return Issue.Field.named(field);
        }

        private Maybe<String> convert(T value) {
            return conversion.call(value);
        }

        private Action<String> setProperty(final Mingle.Project.Card card) {
            return new Action<String>() {
                public void call(String converted) {
                    card.property(property, converted);
                }
            };
        }

        private NullaryAction logUnmappable(final T value) {
            return new NullaryAction() {
                public void call() {
                    logger.unmappableValue(field, value);
                }
            };
        }
    }
}
