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

import static com.thoughtworks.mingleconnector.Maybe.*;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.List;
import java.util.Date;
import java.util.Map;
import com.natpryce.makeiteasy.*;
import static com.natpryce.makeiteasy.Property.newProperty;
import static com.natpryce.makeiteasy.MakeItEasy.*;
import org.hamcrest.BaseMatcher;
import org.hamcrest.Description;
import org.hamcrest.Matcher;
import org.mockito.stubbing.Answer;
import org.mockito.internal.stubbing.answers.Returns;

public class TestSupport {

    public static class Makers {
        public static final Property<Issue, String> type = newProperty();
        public static final Property<Issue, String> summary = newProperty();
        public static final Property<Issue, String> url = newProperty();
        public static final Property<Issue, String> key = newProperty();
        public static final Property<Issue, String> project = newProperty();
        public static final Property<Issue, String> projectName = newProperty();
        public static final Property<Issue, String> description = newProperty();
        public static final Property<Issue, String> created = newProperty();
        public static final Property<Issue, String> priority = newProperty();
        public static final Property<Issue, String> assignee = newProperty();
        public static final Property<Issue, String> dueDate = newProperty();
        public static final Property<Issue, String> reporter = newProperty();

        public static final Instantiator<Issue> Issue = new Instantiator<Issue>() {
            public Issue instantiate(PropertyLookup<Issue> lookup) {
                return new InMemoryIssue(lookup.valueOf(type, "default-type"),
                                         lookup.valueOf(key, "default-key"),
                                         lookup.valueOf(summary, "default-summary"),
                                         lookup.valueOf(description, "default-description"),
                                         lookup.valueOf(created, "1970-01-01T12:00:00"),
                                         lookup.valueOf(dueDate, "1970-01-01T12:00:00"),
                                         lookup.valueOf(priority, "default-priority"),
                                         lookup.valueOf(assignee, "default-assignee"),
                                         lookup.valueOf(reporter, "default-reporter"),
                                         lookup.valueOf(url, "default-url"),
                                         lookup.valueOf(project, "default-project"),
                                         lookup.valueOf(projectName, "default-project-name"));
            }
        };

        public static final Property<Event, Boolean> isPassToDevelopment = newProperty();
        public static final Property<Event, Issue> issue = newProperty();
        public static final Instantiator<Event> Event = new Instantiator<Event>() {
            public Event instantiate(final PropertyLookup<Event> lookup) {
                return new Event(lookup.valueOf(issue, make(an(Issue))), null, null) {
                    public boolean isPassToDevelopment() {
                        return lookup.valueOf(isPassToDevelopment, true);
                    }
                };
            }
        };
    }

    public static class InMemoryIssue implements Issue {
        public String mingleUrl;
        private final String type;
        private final String key;
        private final String summary;
        private final String description;
        private final String created;
        private final String dueDate;
        private final String url;
        private final String project;
        private final String projectName;
        private final String priority;
        private final String assignee;
        private final String reporter;

        public InMemoryIssue(String type, String key, String summary, String description,
                             String created, String dueDate, String priority, String assignee,
                             String reporter, String url, String project, String projectName) {
            this.type = type; this.key = key; this.summary = summary;
            this.description = description; this.created = created; this.dueDate = dueDate;
            this.priority = priority; this.assignee = assignee; this.reporter = reporter;
            this.url = url; this.project = project; this.projectName = projectName;
        }

        public String key() { return key; }
        public String type() { return type; }
        public String summary() { return summary; }
        public String description() { return description; }

        public <T> Maybe<T> field(Field<T> field) {
            if (field == Field.ASSIGNEE) return (Maybe<T>) definitely(assignee);
            if (field == Field.REPORTER) return (Maybe<T>) definitely(reporter);
            if (field == Field.PROJECT) return (Maybe<T>) definitely(projectName);
            if (field == Field.KEY) return (Maybe<T>) definitely(key);
            if (field == Field.CREATED) return (Maybe<T>) definitely(parseDate(created));
            if (field == Field.DUE_DATE) return (Maybe<T>) definitely(parseDate(dueDate));
            if (field == Field.PRIORITY) return (Maybe<T>) definitely(priority);
            throw new RuntimeException("Unknown field " + field);
        }

        public String url() { return url; }
        public String project() { return project; }
        public void mingleUrl(String url) { mingleUrl = url; }

        private Date parseDate(String date) {
            try {
                return new SimpleDateFormat("yyyy-MM-dd'T'hh:mm:ss").parse(date);
            } catch (ParseException e) {
                throw new RuntimeException(e);
            }
        }
    }

    public static class StubWeb implements Web {
        private String location;

        public Response post(String url, List params) {
            return new StubResponse() {
                public String header(String name) {
                    if (name.equals("Location")) return location;
                    return null;
                }
            };
        }

        public StubWeb withLocation(String location) {
            this.location = location;
            return this;
        }
    }

    public static class CannedResponseWeb implements Web {
        private final Response response;
        public CannedResponseWeb(Response response) { this.response = response; }
        public Response post(String url, List params) {
            return response;
        }
    }

    public static class CannedStatusWeb extends CannedResponseWeb {
        public CannedStatusWeb(final int status) {
            super(new StubResponse() {
                    public int statusCode() {
                        return status;
                    }
                });
        }
    }

    public static Answer<Object> returning(Object value) {
        return new Returns(value);
    }

    public static class StubResponse implements Web.Response {
        public String header(String name) {
            return "http://stub-web/api/v2/projects/stub-web/cards/0.xml";
        }

        public int statusCode() {
            return 0;
        }

        public String body() {
            return "Some body";
        }
    }

    public static Matcher<Map> hasEntry(String name, String value) {
        return new HasEntry(name, value);
    }

    private static class HasEntry extends BaseMatcher<Map> {
        private final Object key;
        private final Object value;
        public HasEntry(Object key, Object value) {
            this.key = key;
            this.value = value;
        }

        public boolean matches(Object o) {
            Map map = (Map) o;
            return map.containsKey(key) && map.get(key) != null && map.get(key).equals(value);
        }

        public void describeTo(Description description) {
            description.appendText("map with {"+key+"="+value+"}");
        }
    }

    public static Matcher<List> hasItem(Object item) {
        return new HasItem(item);
    }

    private static class HasItem extends BaseMatcher<List> {
        private final Object item;
        public HasItem(Object item) {
            this.item = item;
        }

        public boolean matches(Object list) {
            return ((List) list).contains(item);
        }

        public void describeTo(Description description) {
            description.appendText("list containing " + item);
        }
    }

    public static Matcher<String> containsString(String substring) {
        return new ContainsString(substring);
    }
    public static class ContainsString extends BaseMatcher<String> {
        private final String substring;
        public ContainsString(String substring) { this.substring = substring; }
        public boolean matches(Object s) { return ((String) s).contains(substring); }
        public void describeTo(Description d) { d.appendText("string containing '" +substring+"'"); }
    }

    public static <T> Matcher<T> not(Matcher<T> matcher) {
        return new IsNot<T>(matcher);
    }

    public static class IsNot<T> extends BaseMatcher<T>  {
        private final Matcher<T> matcher;

        public IsNot(Matcher<T> matcher) {
            this.matcher = matcher;
        }

        public boolean matches(Object arg) {
            return !matcher.matches(arg);
        }

        public void describeTo(Description description) {
            description.appendText("not ").appendDescriptionOf(matcher);
        }
    }
}
