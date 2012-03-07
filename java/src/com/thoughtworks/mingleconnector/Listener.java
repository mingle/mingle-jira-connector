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

import com.atlassian.jira.event.issue.AbstractIssueEventListener;
import com.atlassian.jira.event.issue.IssueEvent;

public class Listener extends AbstractIssueEventListener {
    private final Logger logger = new Log4JLogger();
    private Config config;

    public String[] getAcceptedParams() { return Config.Property.names(); }
    public void init(Map params) { config = new Config(params); }
    public String getDescription() {
        return "Mingle-JIRA Connector. Enter the details of your " +
            "Mingle server and specify the mappings that you require. All properties are " +
            "mandatory unless specified otherwise." +
            "<br><br>" +
            "The Mingle server URL provided must be accessible not only from the JIRA server, " +
            "but also from the browsers of JIRA users." +
            "<br><br>" +
            "Mappings must be of the form" +
            "<br><br>" +
            "&nbsp;&nbsp;&nbsp;&nbsp;left-value=>right-value, other-left-value=>other-right-value"+
            "<br><br>" +
            "For the project mappings, the left values are JIRA project keys and the right " +
            "values are Mingle project identifiers. Each JIRA project must be associated with " +
            "exactly one Mingle project; each Mingle project may be associated with one or more " +
            "JIRA projects." +
            "<br><br>" +
            "For the handover status mappings, the left values are JIRA project keys and the right " +
            "values are the JIRA status which triggers handover to Mingle. " +
            "Each JIRA project requires exactly one handover status." +
            "<br><br>" +
            "For the type mappings, the left values are JIRA issue types and the right values " +
            "the corresponding Mingle card types. If an issue is passed whose type does not " +
            "appear in this mapping then the type of the card created will be the same as that " +
            "of the originating issue. This property is optional." +
            "<br><br>" +
            "For the property mappings, the left values are JIRA fields and the right values " +
            "the Mingle properties that they should be mapped to. Available JIRA fields are " +
            "Assignee, Reporter, Created, Due Date, Priority and Project. " +
            "Only specify the fields you want copied to new cards. This property is optional." +
            "<br><br>" +
            "For the initial card values, the left values are Mingle properties and the right values " +
            "the initial value that they should be mapped to. This property is optional." +
            "<br><br>";
    }

    public void workflowEvent(final IssueEvent event) {
        eventHandler().handle(new Event(new Jira.Issue(event.getIssue(), logger),
                                        new Jira.Changes(event), new Workflow(config.handoverStatuses())));
    }

    private EventHandler eventHandler() {
        Web web = new ResponseValidatingWebClient(
                        new LoggingWebClient(
                              new WebClient(config.user(), config.password()),
                              logger));
        final Mingle mingle = new Mingle(new WebAPI(web), config.mingle());

        ProjectMap projectMap = new SimpleProjectMap(config.projects(), mingle);
        return new EventHandler(logger,
                                new CardFactory(config.types(), config.properties(),
                                                projectMap, config.initialCardValues(),
                                                config.priorities(), logger));
    }
}
