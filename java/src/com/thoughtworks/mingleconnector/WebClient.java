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

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.HttpMethod;
import org.apache.commons.httpclient.NameValuePair;
import org.apache.commons.httpclient.UsernamePasswordCredentials;
import org.apache.commons.httpclient.methods.PostMethod;

public class WebClient implements Web {
    private final HttpClient client = new HttpClient();
    public WebClient(String username, String password) {
        setCredentials(username, password);
    }

    public Response post(String url, List params) {
        HttpMethod request = postRequest(url, params);
        execute(request);
        return new HttpClientResponse(request);
    }

    private HttpMethod postRequest(String url, List params) {
        PostMethod request = new PostMethod(url);
        request.setRequestBody(params(params));
        request.addRequestHeader("Content-Type",
                                 "application/x-www-form-urlencoded; charset=UTF-8");
        return request;
    }

    private NameValuePair[] params(List params) {
        List<NameValuePair> pairs = new ArrayList<NameValuePair>();
        for (Object o : params) {
            Param param = (Param) o;
            pairs.add(new NameValuePair(param.name, param.value));
        }
        return pairs.toArray(new NameValuePair[0]);
    }

    private void execute(HttpMethod request) {
        try {
            client.executeMethod(request);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private void setCredentials(String username, String password) {
        client.getState().setCredentials(null, null,
                                         new UsernamePasswordCredentials(username, password));
    }

    private class HttpClientResponse implements Response {
        private final HttpMethod request;
        public HttpClientResponse(HttpMethod request) {
            this.request = request;
        }

        public int statusCode() {
            return request.getStatusCode();
        }

        public String header(String name) {
            return request.getResponseHeader(name).getValue();
        }

        public String body() {
            try {
                return request.getResponseBodyAsString();
            } catch(IOException ex) {
                throw new RuntimeException(ex);
            }
        }
    }
}
