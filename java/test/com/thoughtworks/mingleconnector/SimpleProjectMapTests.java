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
import java.util.*;

public class SimpleProjectMapTests {
    @Test public void asksMingleForTheMappedProject() {
        Mingle mingle = mock(Mingle.class);
        Mingle.Project project = mock(Mingle.Project.class);
        Mapping map = Mapping.fromMap(new HashMap<String, String>() {{
                    put("jira-project", "mingle-project");
                }});
        stub(mingle.project("mingle-project")).toReturn(project);
        assertSame(new SimpleProjectMap(map, mingle).get("jira-project"), project);
    }

    @Test(expected=IllegalArgumentException.class) public void whenAskedForAProjectThatDoesntExist() {
        new SimpleProjectMap(Mapping.empty(), null).get("anything");
    }
}
