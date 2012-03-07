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

class LoggingWebClient implements Web {
    private final Web wrapped;
    private final Logger logger;
    public LoggingWebClient(Web wrapped, Logger logger) {
        this.wrapped = wrapped;
        this.logger = logger;
    }

    public Response post(String url, List params) {
        logger.webPost(url, params);
        Response response = wrapped.post(url, params);
        logger.webResponse(response.statusCode());
        return response;
    }
}
