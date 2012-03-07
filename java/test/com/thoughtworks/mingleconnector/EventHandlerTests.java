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

import java.util.HashMap;
import java.util.Map;

import static com.natpryce.makeiteasy.MakeItEasy.*;
import static com.thoughtworks.mingleconnector.TestSupport.*;
import static com.thoughtworks.mingleconnector.TestSupport.Makers.*;
import static org.junit.Assert.*;
import org.junit.*;
import static org.mockito.Mockito.*;

public class EventHandlerTests {
    private final Mingle.API api = mock(Mingle.API.class);
    private final Logger logger = mock(Logger.class);
    private final ProjectMap projectMap = mock(ProjectMap.class);
    private final Mapping priorityMap = Mapping.empty();
    private Map<String, String> typeMap = new HashMap<String, String>();
    private Mapping constantMap = Mapping.empty();
    final Map<String, String> propertyMap = new HashMap<String, String>() {{
            put("Project", "Tool");
            put("Assignee", "Support Owner");
            put("Created", "Issue Created");
            put("Due Date", "Due Date");
            put("Priority", "Priority");
            put("Reporter", "Support Reporter");
        }};

    private EventHandler handler() {
        return new EventHandler(logger,
                                new CardFactory(Mapping.fromMap(typeMap),
                                                Mapping.fromMap(propertyMap),
                                                projectMap(),
                                                constantMap, priorityMap, logger));
    }

    private ProjectMap projectMap() {
        Mingle.Project mingleProject = new Mingle.Project(api, null, "a-project");
        stub(projectMap.get(anyString())).toReturn(mingleProject);
        return projectMap;
    }

    @Test public void createsACardIfTheIssueIsBeingPassedToDev() {
        handler().handle(make(an(Event, with(isPassToDevelopment, true))));
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               anyMap());
    }

    @Test public void doesntCreateACardIfTheIssueIsNotBeingPassedToDev() {
        handler().handle(make(an(Event, with(isPassToDevelopment, false))));
        verify(api, never()).createCard(anyString(), anyString(), anyString(), anyString(),
                                        anyString(), anyMap());
    }

    @Test public void createsACardOfTheTypeSpecifiedByTheMap() {
        typeMap = new HashMap<String, String>() {{
                put("feature request", "Feature");
            }};
        handler().handle(make(an(Event, with(issue, an(Issue, with(type, "feature request"))))));
        verify(api).createCard(anyString(), anyString(), eq("Feature"), anyString(), anyString(),
                               anyMap());
    }

    @Test public void createsACardOfTheSameTimeAsTheIssueIfTheTypeHasNoMappingDefined() {
        handler().handle(make(an(Event, with(issue, an(Issue, with(type, "Bug"))))));
        verify(api).createCard(anyString(), anyString(), eq("Bug"), anyString(), anyString(),
                               anyMap());
    }

    @Test public void expectsIssueTypesInTheMapToBeLowerCaseToCopeWithInconsistentCaseOfNamesInConfiguration() {
        typeMap = new HashMap<String, String>() {{
                put("feature request", "Feature");
            }};
        handler().handle(make(an(Event, with(issue, an(Issue, with(type, "Feature Request"))))));
        verify(api).createCard(anyString(), anyString(), eq("Feature"), anyString(), anyString(),
                               anyMap());
    }

    @Test public void createsACardWithTheIssuesSummaryAsAName() {
        handler().handle(make(an(Event, with(issue, an(Issue, with(summary, "the-summary"))))));
        verify(api).createCard(anyString(), anyString(), anyString(), eq("the-summary"),
                               anyString(), anyMap());
    }

    @Test public void createsACardWithDescriptionContainingTheIssuesURL() {
        handler().handle(make(an(Event, with(issue, an(Issue, with(url, "the-url"))))));
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(),
                               argThat(containsString("the-url")), anyMap());
    }

    @Test public void createsACardWithDescriptionContainingTheIssuesDescription() {
        handler().handle(make(an(Event, with(issue, an(Issue, with(description, "The issue's description"))))));
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(),
                               argThat(containsString("The issue's description")), anyMap());
    }

    @Test public void createsACardWithTheMingleProject() {
        handler().handle(make(an(Event, with(issue, an(Issue)))));
        verify(api).createCard(anyString(), eq("a-project"), anyString(), anyString(),
                               anyString(), anyMap());
    }

    @Test public void usesTheIssuesProjectToGetTheMingleProject() {
        handler().handle(make(an(Event, with(issue, an(Issue, with(project, "jira-project"))))));
        verify(projectMap).get(eq("jira-project"));
    }

    @Test public void setsTheIssueKeyOnTheCard() {
        Event event = make(an(Event, with(issue, an(Issue, with(key, "the-key")))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("JIRA issue", "the-key")));
    }

    @Test public void addsTheUrlOfTheOnTheNewCardToTheIssue() {
        Event event = make(an(Event));
        stub(api.createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                            anyMap()))
            .toReturn("the-url");
        handler().handle(event);
        assertEquals("the-url", ((InMemoryIssue) event.issue()).mingleUrl);
    }

    @Test public void InitialCardValues() {
        constantMap.add("Card Property", "Always the same");

        Event event = make(an(Event, with(issue, an(Issue))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("Card Property", "Always the same")));
    }

    @Test public void doesntSetCardsPropertyIfTheFieldHasntBeenMapped() {
        propertyMap.remove("Project");
        Event event = make(an(Event, with(issue, an(Issue, with(projectName, "project-name")))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(not(hasEntry(null, "project-name"))));
    }

    @Test public void setsTheCardsToolUsingIssuesProjectName() {
        Event event = make(an(Event, with(issue, an(Issue, with(projectName, "project-name")))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("Tool", "project-name")));
    }

    @Test public void setsTheCardsIssueRaisedUsingTheIssuesCreatedDate() {
        Event event = make(an(Event, with(issue, an(Issue, with(created, "2011-12-24T12:22:14")))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("Issue Created", "24 Dec 2011")));
    }

    @Test public void setsTheCardsPriorityUsingThePriorityMapWithIssuesPriority() {
        Event event = make(an(Event, with(issue, an(Issue, with(priority, "JDI")))));
        priorityMap.add("JDI", "JUMP");
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("Priority", "JUMP")));
    }

    @Test public void doesNotSetTheCardsPriorityIfTheIssuesValueIsUnMapped() {
        Event event = make(an(Event, with(issue, an(Issue, with(priority, "Who Knows")))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(not(hasEntry("Priority", null))));
    }

    @Test public void logsIfTheIssuesPriorityIsUnmapped() {
        Event event = make(an(Event, with(issue, an(Issue, with(priority, "Who Knows")))));
        handler().handle(event);
        verify(logger).unmappableValue("Priority", "Who Knows");
    }

    @Test public void setsTheSupportOwnerOnTheCardToTheIssuesAssignee() {
        Event event = make(an(Event, with(issue, an(Issue, with(assignee, "Dan Debunk")))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("Support Owner", "Dan Debunk")));
    }

    @Test public void setsTheDueDateToThatOfTheIssue() {
        Event event = make(an(Event, with(issue, an(Issue, with(dueDate,
                                                                "1975-06-30T00:00:00")))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("Due Date", "30 Jun 1975")));
    }

    @Test public void setsTheReporterToThatOfTheIssue() {
        Event event = make(an(Event, with(issue, an(Issue, with(reporter,
                                                                "Robert")))));
        handler().handle(event);
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("Support Reporter", "Robert")));
    }

    @Test public void logsThatItHandledAnEvent() {
        Event event = make(an(Event));
        handler().handle(event);
        verify(logger).handledEvent(event);
    }

    @Test public void logsThatItHandledAnEventEvenIfItIsntPassToDev() {
        Event event = make(an(Event, with(isPassToDevelopment, false)));
        handler().handle(event);
        verify(logger).handledEvent(event);
    }

    @Test public void logsThatItCreatedACard() {
        stub(api.createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                            anyMap()))
            .toReturn("the-url");
        handler().handle(make(an(Event)));
        verify(logger).cardCreated("the-url");
    }
}
