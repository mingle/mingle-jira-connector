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

public class LoggingWebClientTests {
    private Web wrapped = new StubWeb();
    private Logger logger = mock(Logger.class);
    private Web client() { return new LoggingWebClient(wrapped, logger); }

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

    @Test public void logsTheUrl() {
        client().post("a-url", null);
        verify(logger).webPost(eq("a-url"), anyList());
    }

    @Test public void logsTheParameters() {
        List params = new ArrayList() {{add("One");}};
        client().post(null, params);
        verify(logger).webPost(anyString(), eq(params));
    }

    @Test public void logsTheResponsesStatus() {
        wrapped = new CannedStatusWeb(550);
        client().post(null, null);
        verify(logger).webResponse(550);
    }
}
