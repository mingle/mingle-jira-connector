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
package com.atlassian.jira.issue;

import java.sql.Timestamp;

import com.atlassian.jira.issue.issuetype.IssueType;
import com.atlassian.jira.project.Project;
import com.atlassian.jira.issue.priority.Priority;
import com.opensymphony.user.User;

public interface Issue {
    public String getKey();
    public IssueType getIssueTypeObject();
    public String getSummary();
    public String getDescription();
    public Timestamp getCreated();
    public Timestamp getDueDate();
    public Project getProjectObject();
    public Priority getPriorityObject();
    public User getAssignee();
    public User getReporter();
}
