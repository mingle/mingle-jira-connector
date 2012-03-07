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

import java.util.Map;
import java.util.HashMap;

import static com.thoughtworks.mingleconnector.TestSupport.*;

import static org.hamcrest.CoreMatchers.*;
import static org.junit.Assert.*;
import org.junit.Test;
import static org.mockito.Mockito.*;

public class WebAPITests {
    private Web web = mock(Web.class, returning(new StubResponse()));
    private WebAPI api() { return new WebAPI(web); }

    @Test public void postsARequestToCreateACard() {
        api().createCard("the-server", "the-project", null, null, null, new HashMap());
        verify(web).post(eq("the-server/api/v2/projects/the-project/cards.xml"), anyList());
    }

    @Test public void createsACardOfTheSpecifiedType() {
        api().createCard(null, null, "Bug", null, null, new HashMap());
        verify(web).post(anyString(),
                         argThat(hasItem(new Web.Param("card[card_type_name]", "Bug"))));
    }

    @Test public void createsACardWithTheSpecifiedName() {
        api().createCard(null, null, null, "the-name", null, new HashMap());
        verify(web).post(anyString(), argThat(hasItem(new Web.Param("card[name]", "the-name"))));
    }

    @Test public void createsACardWithTheSpecifiedDescription() {
        api().createCard(null, null, null, null, "the-description", new HashMap());
        verify(web).post(anyString(),
                         argThat(hasItem(new Web.Param("card[description]", "the-description"))));
    }

    @Test public void createsACardWithTheSpecifiedProperties() {
        Map<Object, Object> properties = new HashMap<Object, Object>();
        properties.put("fish", "gruff");
        api().createCard(null, null, null, null, null, properties);
        verify(web).post(anyString(),
                         argThat(allOf(hasItem(new Web.Param("card[properties][][name]", "fish")),
                                       hasItem(new Web.Param("card[properties][][value]", "gruff")))));
    }

    @Test public void convertsTheUrlOfTheNewlyCreatedCardToUIFormat() {
        web = new StubWeb().withLocation("http://s/api/v2/projects/p/cards/81.xml");
        String url = api().createCard(null, null, null, null, null, new HashMap());
        assertThat(url, equalTo("http://s/projects/p/cards/81"));
    }
}
