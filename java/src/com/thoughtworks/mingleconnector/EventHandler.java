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

public class EventHandler {
    private final Logger logger;
    private final CardFactory cardFactory;

    public EventHandler(Logger logger, CardFactory cardFactory) {
        this.logger = logger;
        this.cardFactory = cardFactory;
    }

    public void handle(Event event) {
        logger.handledEvent(event);
        if (!event.isPassToDevelopment()) return;
        Issue issue = event.issue();
        Mingle.Project.Card card = createCard(issue);
        issue.mingleUrl(card.url());
    }

    private Mingle.Project.Card createCard(Issue issue) {
        Mingle.Project.Card card = cardFactory.createCard(issue);
        card.save();
        logger.cardCreated(card.url());
        return card;
    }
}
