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

import java.util.Date;
import static org.junit.Assert.*;
import org.junit.*;
import static org.mockito.Mockito.*;

public class JiraTests {
    private final Jira.Issue issue;
    public JiraTests() {
        com.atlassian.jira.issue.Issue jiraIssue = mock(com.atlassian.jira.issue.Issue.class);
        issue = new Jira.Issue(jiraIssue, null);
    }

    @Test public void issueReturnsBlankDescriptionsWhenJiraGivesNulls() {
        assertEquals("", issue.description());
    }

    @Test public void issueReturnsBlankAssigneeWhenJiraGivesNull() {
        assertHasNoValue(issue.field(Issue.Field.ASSIGNEE));
    }

    @Test public void issueReturnsNothingWhenJiraGivesNullForDueDate() {
        assertHasNoValue(issue.field(Issue.Field.DUE_DATE));
    }

    private <T> void assertHasNoValue(Maybe<T> maybe) {
        final Holder<Boolean> hasValue = new Holder<Boolean>(false);
        maybe.ifValue(new Action<T>() {
                public void call(T value) {
                    hasValue.value = true;
                }
            });
        assertFalse(hasValue.value);
    }
}
