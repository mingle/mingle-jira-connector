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

public class WorkflowTests {
    private final Event.Workflow workflow = new Workflow(Mapping.parse("PRJ=>In QA"));

    @Test public void isInDevelopmentWhenStatusMatchesWithHandoverStatusForIssuesProject() {
        Event.Changes changes = mock(Event.Changes.class);
        stub(changes.status()).toReturn("In QA");

        Issue issue = make(an(Issue, with(project, "PRJ")));

        assertTrue(workflow.isPassToDevelopment(changes, issue));
    }

    @Test public void isNotInDevelopmentWhenStatusDoesntMatchHandoverStatusForIssuesProject() {
        Event.Changes changes = mock(Event.Changes.class);
        stub(changes.status()).toReturn("In Development");

        Issue issue = make(an(Issue, with(project, "PRJ")));

        assertFalse(workflow.isPassToDevelopment(changes, issue));
    }

    @Test public void isNotInDevelopmentWhenIssuesProjectIsNotKnown() {
        Event.Changes changes = mock(Event.Changes.class);
        Issue issue = make(an(Issue, with(project, "NON")));

        assertFalse(workflow.isPassToDevelopment(changes, issue));
    }
}
