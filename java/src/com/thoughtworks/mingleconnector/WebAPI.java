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

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.*;

public class WebAPI implements Mingle.API {
    private final Web web;
    public WebAPI(Web web) {
        this.web = web;
    }

    public String createCard(String server, String project, String type, String name,
                             String description, Map properties) {
        Web.Response response = web.post(urlFor(server, project),
                                         paramsFor(type, name, description, properties));
        return apiToUI(response.header("Location"));
    }

    private static String urlFor(String server, String project) {
        return server+"/api/v2/projects/"+project+"/cards.xml";
    }

    private static List<Web.Param> paramsFor(String type, String name, String description,
                                             Map properties) {
        List<Web.Param> params = new ArrayList<Web.Param>();
        params.add(new Web.Param("card[name]", name));
        params.add(new Web.Param("card[card_type_name]", type));
        params.add(new Web.Param("card[description]", description));
        for (Object o : properties.entrySet()) {
            Map.Entry entry = (Map.Entry) o;
            params.add(new Web.Param("card[properties][][name]", (String) entry.getKey()));
            params.add(new Web.Param("card[properties][][value]", (String) entry.getValue()));
        }
        return params;
    }

    private String apiToUI(String apiURL) {
        Pattern pattern = Pattern.compile("(.*)/api/v2(.*).xml");
        Matcher matcher = pattern.matcher(apiURL);
        matcher.matches();
        return matcher.group(1) + matcher.group(2);
    }
}

