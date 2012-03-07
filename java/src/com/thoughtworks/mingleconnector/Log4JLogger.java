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

public class Log4JLogger implements Logger {
    private final org.apache.log4j.Logger logger = org.apache.log4j.Logger.getLogger("mingle-connector");
    public void handledEvent(Event event) {
        event.complete(new Event.Description() {
                public void details(String issueKey, String newStatus) {
                    logger.info("Received an event on " + issueKey + " with status " + newStatus);
                }
            });
    }

    public void webPost(String url, List params) {
        logger.debug("Posted to " + url + " with parameters '" + params + "'.");
    }

    public void webResponse(int statusCode) {
        logger.debug("Received the response code " + statusCode);
    }

    public void cardCreated(String url) {
        logger.info("Created Mingle card at " + url);
    }

    public void settingCustomField(String issueKey, String fieldName, String value) {
        logger.debug("Setting custom field on issue "+issueKey+": '"+fieldName+"'='"+value+"'");
    }

    public void unmappableValue(String field, Object value) {
        logger.error("Could not map field " + field + " with value " + value);
    }
}
