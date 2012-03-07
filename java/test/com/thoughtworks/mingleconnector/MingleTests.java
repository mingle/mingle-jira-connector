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

import static com.thoughtworks.mingleconnector.TestSupport.*;

import static org.junit.Assert.*;
import org.junit.Test;
import static org.mockito.Mockito.*;

public class MingleTests {
    private Mingle.API api = mock(Mingle.API.class);
    private String server;
    private Mingle mingle() { return new Mingle(api, server); }

    @Test public void createsACardOnTheServer() {
        server = "http://the-server:8080";
        createCard(null, null, null, null);
        verify(api).createCard(eq(server), anyString(), anyString(), anyString(), anyString(),
                               anyMap());
    }

    @Test public void createsACardInTheProject() {
        createCard("the-project", null, null, null);
        verify(api).createCard(anyString(), eq("the-project"), anyString(), anyString(),
                               anyString(), anyMap());
    }

    @Test public void createsACardOfTheSpecifiedType() {
        createCard(null, "Bug", null, null);
        verify(api).createCard(anyString(), anyString(), eq("Bug"), anyString(), anyString(),
                               anyMap());
    }

    @Test public void createsACardWithTheSpecifiedName() {
        createCard(null, null, "the-name", null);
        verify(api).createCard(anyString(), anyString(), anyString(), eq("the-name"), anyString(),
                               anyMap());
    }

    @Test public void createsACardWithTheSpecifiedDescription() {
        createCard(null, null, null, "the-description");
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(),
                               eq("the-description"), anyMap());
    }

    @Test public void setsAPropertyOnTheCard() {
        creator().withProperty("the-property-name", "the-property-value").create();
        verify(api).createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                               argThat(hasEntry("the-property-name", "the-property-value")));
    }

    @Test public void hangsOnToTheURLOfTheCard() {
        when(api.createCard(anyString(), anyString(), anyString(), anyString(), anyString(),
                            anyMap()))
            .thenReturn("the-url");
        Mingle.Project.Card card = createCard(null, null, null, null);
        assertEquals("the-url", card.url());
    }

    private Creator creator() { return new Creator(); }

    private class Creator {
        private String project;
        private String type;
        private String name;
        private String description;
        private String issue;
        private String propertyName;
        private String propertyValue;

        public Mingle.Project.Card create() {
            Mingle.Project.Card card =  mingle().project(project).addCard(type, name, description);
            card.property(propertyName, propertyValue);
            card.save();
            return card;
        }

        public Creator withProject(String project) {
            this.project = project;
            return this;
        }

        public Creator withType(String type) {
            this.type = type;
            return this;
        }

        public Creator withName(String name) {
            this.name = name;
            return this;
        }

        public Creator withDescription(String description) {
            this.description = description;
            return this;
        }

        public Creator withIssue(String issue) {
            this.issue = issue;
            return this;
        }

        public Creator withProperty(String name, String value) {
            this.propertyName = name;
            this.propertyValue = value;
            return this;
        }
    }

    private Mingle.Project.Card createCard(String project, String type, String name,
                                           String description) {
        return new Creator().withProject(project).withType(type).withName(name)
            .withDescription(description).create();
    }
}
