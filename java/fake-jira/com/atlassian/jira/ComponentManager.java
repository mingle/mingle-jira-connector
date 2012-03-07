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
package com.atlassian.jira;

import com.atlassian.jira.config.properties.ApplicationProperties;
import com.atlassian.jira.issue.CustomFieldManager;
import com.atlassian.jira.issue.Issue;
import com.atlassian.jira.issue.fields.CustomField;
import com.thoughtworks.mingleconnector.JiraSimulator;

public class ComponentManager {
    private static JiraSimulator jira;

    public static void jira(JiraSimulator jira) {
        ComponentManager.jira = jira;
    }

    public static ComponentManager getInstance() {
        return new ComponentManager();
    }

    public CustomFieldManager getCustomFieldManager() {
        return new CustomFieldManager() {
            public CustomField getCustomFieldObjectByName(final String name) {
                return new CustomField() {
                    public void createValue(Issue issue, Object value) {
                        jira.updateProperty(issue.getKey(), name, value);
                    }
                };
            }
        };
    }

    public ApplicationProperties getApplicationProperties() {
        return new ApplicationProperties() {
            public String getString(String name) {
                return jira.baseURL();
            }
        };
    }
}
