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

import static com.natpryce.makeiteasy.MakeItEasy.*;
import static com.thoughtworks.mingleconnector.TestSupport.*;
import static com.thoughtworks.mingleconnector.TestSupport.Makers.*;
import static org.junit.Assert.*;
import org.junit.*;
import static org.mockito.Mockito.*;

public class EventTests {
    @Test public void isPassToDevelopmentWhenWorkflowIs() {
        assertTrue(new Event(null, mock(Event.Changes.class), new WorkflowIncludingPassToDevelopment())
                   .isPassToDevelopment());
    }

    @Test public void isNotPassToDevelopmentWhenWorkflowIsnt() {
        assertFalse(new Event(null, mock(Event.Changes.class), new WorkflowNotIncludingPassToDevelopment())
                   .isPassToDevelopment());
    }

    @Test public void describesIssueKey() {
        Event.Description description = mock(Event.Description.class);
        Event event = new Event(make(an(Issue, with(key, "1234"))),
                                mock(Event.Changes.class), new WorkflowNotIncludingPassToDevelopment());
        event.complete(description);
        verify(description).details(eq("1234"), anyString());
    }

    @Test public void describesChangedStatus() {
        Event.Description description = mock(Event.Description.class);
        Event.Changes changes = mock(Event.Changes.class);
        stub(changes.status()).toReturn("In Development");
        Event event = new Event(make(an(Issue)), changes, new WorkflowNotIncludingPassToDevelopment());
        event.complete(description);
        verify(description).details(anyString(), eq("In Development"));
    }

    private class WorkflowIncludingPassToDevelopment implements Event.Workflow {
        public boolean isPassToDevelopment(Event.Changes changes, Issue issue) {
            return true;
        }
    }

    private class WorkflowNotIncludingPassToDevelopment implements Event.Workflow {
        public boolean isPassToDevelopment(Event.Changes changes, Issue issue) {
            return false;
        }
    }
}
