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

import java.util.Collections;
import java.util.Date;
import java.util.List;

import com.atlassian.jira.ComponentManager;
import com.atlassian.jira.config.properties.APKeys;
import com.atlassian.jira.event.issue.IssueEvent;
import com.atlassian.jira.issue.CustomFieldManager;
import com.atlassian.jira.issue.fields.CustomField;
import com.opensymphony.user.User;
import org.ofbiz.core.entity.GenericEntity;
import org.ofbiz.core.entity.GenericEntityException;
import org.ofbiz.core.entity.GenericValue;

class Jira {
    public static class Changes implements Event.Changes {
        private final IssueEvent event;
        public Changes(IssueEvent event) {
            this.event = event;
        }

        public String status() {
            for (Object o : changes()) {
                GenericEntity change = (GenericEntity) o;
                if ("status".equalsIgnoreCase(change.getString("field"))) {
                    return change.getString("newstring");
                }
            }
            return null;
        }

        private List changes() {
            GenericValue changeLog =  event.getChangeLog();
            if (changeLog == null) return Collections.EMPTY_LIST;
            try {
                return changeLog.getRelated("ChildChangeItem");
            } catch (GenericEntityException e) {
                throw new RuntimeException(e);
            }
        }
    }

    public static class Issue implements com.thoughtworks.mingleconnector.Issue {
        private final ComponentManager components = ComponentManager.getInstance();
        private final com.atlassian.jira.issue.Issue issue;
        private final Logger logger;
        public Issue(com.atlassian.jira.issue.Issue issue, Logger logger) {
            this.issue = issue;
            this.logger = logger;
        }

        public String key() {
            return issue.getKey();
        }

        public String type() {
            return issue.getIssueTypeObject().getName();
        }

        public String summary() {
            return issue.getSummary();
        }

        public String description() {
            return issue.getDescription() == null ? "" : issue.getDescription();
        }

        public <T> Maybe<T> field(Field<T> field) {
            if (field == Field.ASSIGNEE) return (Maybe<T>) fromNullable(issue.getAssignee(), userName());
            if (field == Field.REPORTER) return (Maybe<T>) fromNullable(issue.getReporter(), userName());
            if (field == Field.PROJECT) return (Maybe<T>) definitely(issue.getProjectObject().getName());
            if (field == Field.KEY) return (Maybe<T>) definitely(key());
            if (field == Field.CREATED) return (Maybe<T>) definitely(issue.getCreated());
            if (field == Field.DUE_DATE) return (Maybe<T>) Maybe.fromNullable(issue.getDueDate());
            if (field == Field.PRIORITY) return (Maybe<T>) definitely(issue.getPriorityObject().getName());
            throw new RuntimeException("Unknown field " + field);
        }

        public String url() {
            return baseURL()+"/browse/" + issue.getKey();
        }

        public String project() {
            return issue.getProjectObject().getKey();
        }

        public void mingleUrl(String url) {
            CustomFieldManager manager = components.getCustomFieldManager();
            CustomField field = manager.getCustomFieldObjectByName("Mingle Card");
            // TESTCASE
            if (field == null) {
                throw new RuntimeException("Custom field 'Mingle Card' does not exist");
            }
            field.createValue(issue, url);
            logger.settingCustomField(key(), "Mingle Card", url);
        }

        private String baseURL() {
            return components.getApplicationProperties().getString(APKeys.JIRA_BASEURL);
        }

        private Function<User, String> userName() {
            return new Function<User, String>() {
                public String call(User user) {
                    return user.getFullName();
                }
            };
        }
    }
}
