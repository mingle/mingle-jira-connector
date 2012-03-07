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

import static org.junit.Assert.*;
import org.junit.*;
import static org.mockito.Mockito.*;
import java.util.ArrayList;
import java.util.List;
import static com.thoughtworks.mingleconnector.TestSupport.*;

public class ResponseValidatingWebClientTests {
    private Web wrapped;
    private ResponseValidatingWebClient client() { return new ResponseValidatingWebClient(wrapped); }

    @Test public void callsTheDecoratedWebClientForPosts() {
        wrapped = mock(Web.class);
        String url = "fake-url";
        List params = new ArrayList() {{add("One");}};
        when(wrapped.post(url, params)).thenReturn(new StubResponse());

        client().post(url, params);
        verify(wrapped).post(url, params);
    }

    @Test public void returnsTheWebResponse() {
        Web.Response response = new StubResponse();
        wrapped = new CannedResponseWeb(response);
        assertEquals(client().post(null, null), response);
    }

    @Test public void accepts200Responses() {
        wrapped = new CannedStatusWeb(200);
        client().post(null, null);
    }

    @Test public void accepts201Responses() {
        wrapped = new CannedStatusWeb(201);
        client().post(null, null);
    }

    @Test(expected=Exception.class) public void throwsExceptionWhenResponseStatusCodeIs500() {
        wrapped = new CannedResponseWeb(new StubResponse(){
                public int statusCode() { return 500; }
                public String body() { return "the-body"; }
            });
       try {
            client().post("the-url", null);
        } catch(RuntimeException ex) {
            assertTrue(ex.getMessage().contains("500"));
            assertTrue(ex.getMessage().contains("the-url"));
            assertTrue(ex.getMessage().contains("the-body"));
            throw ex;
        }
    }

    @Test(expected=Exception.class) public void throwsExceptionWhenResponseStatusCodeIs401() {
        wrapped = new CannedStatusWeb(401);
        try {
            client().post("a-url", null);
        } catch(RuntimeException ex) {
            assertTrue(ex.getMessage().contains("401"));
            throw ex;
        }

    }
}
