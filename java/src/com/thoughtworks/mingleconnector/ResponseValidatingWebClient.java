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

import java.util.List;

public class ResponseValidatingWebClient implements Web {
    private final Web decorated;

    public ResponseValidatingWebClient(Web decorated) {
        this.decorated = decorated;
    }

    public Web.Response post(String url, List params) {
        Web.Response response = decorated.post(url, params);
        if(response.statusCode() >= 400)
            throw new RuntimeException("Got " + response.statusCode() +
                                       " status code for request to " + url + " with body '" + response.body() + "'.");
        return response;
    }
}
