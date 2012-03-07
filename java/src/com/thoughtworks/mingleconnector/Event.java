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

public class Event {
    private final Issue issue;
    private final Changes changes;
    private final Workflow workflow;

    public Event(Issue issue, Changes changes, Workflow workflow) {
        this.issue = issue;
        this.changes = changes;
        this.workflow = workflow;
    }

    public Issue issue() { return issue; }

    public boolean isPassToDevelopment() {
        return workflow.isPassToDevelopment(changes, issue());
    }

    public void complete(Description description) {
        description.details(issue.key(), changes.status());
    }

    public interface Description {
        public void details(String issueKey, String newStatus);
    }

    public interface Changes {
        String status();
    }

    public interface Workflow {
        boolean isPassToDevelopment(Event.Changes changes, Issue issue);
    }
}
