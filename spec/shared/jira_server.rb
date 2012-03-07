# Copyright 2011 ThoughtWorks, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You may
# obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
# 
require File.dirname(__FILE__) + '/http_server'
$:.unshift File.dirname(__FILE__) + '/../../vendor/gems/hpricot-0.8.2-java/lib/'
require 'hpricot'
require 'observer'

class JiraHttpServer < HttpServer
  attr_accessor :error_on_update_issue, :credentials, :token_received, :error_on_auth, :soap_error_on_auth
  attr_reader :token

  def initialize(port)
    super port
    @issues = {}
    @error_on_update_issue = false
    @error_on_auth = false
    @token = 'abcde'
  end

  def update_issue key, field, value
    issue = issue_with_key(key)
    if issue
      issue[field] = value
    else
      issue = {:key=>key, :type=>"default-type", field=>value}
      add_issue(issue)
    end
  end

  def add_issue issue
    new_issue = Issue.new(issue)
    @issues[new_issue.key] = new_issue
  end

  def issue_with_key key
    @issues[key]
  end

  def issue_with_summary summary
    @issues.values.find {|i| i[:summary] == summary}
  end

  def handler
    Handler.new self
  end

  private
  class Issue
    include Observable
    def initialize(issue)
      issue[:type] or raise "Issues must have a type"
      (issue[:project] || issue[:key]) or raise "Issues must have a project or key"
      issue[:key] ||= "#{issue[:project][:key]}-#{rand(999)}"
      @issue = issue
      @created = Time.now
    end

    def key() @issue[:key] end
    def type() @issue[:type] end
    def summary() @issue[:summary] end
    def status() @issue[:status] end
    def description() @issue[:description] end
    def project() @issue[:project] end
    def priority() @issue[:priority] end
    def has_status?(status) self.status==status end
    def created() @created end
    def assignee() @issue[:assignee] end
    def reporter() @issue[:reporter] end
    def due_date() @issue[:due_date] end

    def [](property)
      @issue[property]
    end

    def []=(property, value)
      changed
      @issue[property] = value
      notify_observers self, property, value
    end

    def inspect
      key
    end
  end

  class Handler
    def handlers
      [{:marker=>'n1:login',                  :method=>:login},
       {:marker=>'n1:updateIssue',            :method=>:update_issue},
       {:marker=>'n1:getAvailableActions',    :method=>:get_available_actions},
       {:marker=>'n1:progressWorkflowAction', :method=>:progress_workflow_action}
      ]
    end

    def initialize jira_data
      @jira_data = jira_data
    end

    def handle(request, response)
      begin
        body = read request
        handler = handlers.find { |r| contains r[:marker], body}
        if handler
          send handler[:method], body, response
        else
          not_found body unless handler
        end
      rescue
        puts "**** I am sorely disappointed to have encountered an error ****"
        puts $!, $@
      end
    end

    private
    def login body, response
      doc = Hpricot.XML body
      username = doc.at('in0').inner_html
      password = doc.at('in1').inner_html
      @jira_data.credentials = {:username=>username, :password=>password}
      if @jira_data.error_on_auth
        error response, login_error_response
      elsif @jira_data.soap_error_on_auth
        error response, miscellaneous_error
      else
        okay response, login_response(@jira_data.token)
      end
    end

    def update_issue body, response
      doc = Hpricot.XML body
      token = Hpricot.XML(body).at('in0').inner_html
      issue = doc.at('in1').inner_html
      field = doc.at('in2 id').inner_html
      value = doc.at('in2 values').inner_html

      @jira_data.token_received = token

      if issue=='missing'
        error response, missing_issue_error
      elsif @jira_data.error_on_update_issue
        error response, miscellaneous_error
      else
        @jira_data.update_issue issue, field, value
        okay response, update_issue_response
      end
    end

    def get_available_actions body, response
      doc = Hpricot.XML body
      issue = doc.at('in1').inner_html
      project = issue.split('-')[0]
      transition = transitions.find { |t| t.project?(project) }
      if transition
        okay response, get_available_actions_response(transition.id, transition.name)
      else
        okay response, get_no_available_actions_response
      end
    end

    def progress_workflow_action body, response
      doc = Hpricot.XML body
      key = doc.at('in1').inner_html
      transition_id = doc.at('in2').inner_html

      if key.include? 'missing'
        error response, missing_issue_error
      elsif @jira_data.error_on_update_issue
        error response, miscellaneous_error
      else
        issue = @jira_data.issue_with_key(key)
        transitions.find { |t| t.id?(transition_id) }.apply_to(issue)
        okay response, progress_workflow_action_response
      end
    end

    def okay response, content
      response.setStatus javax.servlet.http.HttpServletResponse.SC_OK
      response.getWriter.write content
    end

    def error response, content
      response.setStatus javax.servlet.http.HttpServletResponse.SC_INTERNAL_SERVER_ERROR
      response.getWriter.write content
    end

    def contains element, body
      doc = Hpricot.XML body
      !doc.search(element).empty?
    end

    def read request
      reader = request.getReader
      body = ""
      while (line = reader.readLine)
        body += line
        body += "\n"
      end
      body
    end

    def transitions
      [Transition.new('MCONN', '721', 'QA Complete', 'Resolved'),
       Transition.new('QCONN', '11', 'Development Complete', 'Resolved')]
    end

    class Transition
      attr_reader :id, :name
      def initialize project, id, name, new_status
        @project, @id, @name, @new_status = project, id, name, new_status
      end
      def id?(id) @id==id end
      def project?(project) @project==project end
      def apply_to issue
        issue[:status] = @new_status
      end
    end
  end
end

def login_response(token)
  <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Body>
    <ns1:loginResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
        xmlns:ns1="http://soap.rpc.jira.atlassian.com">
      <loginReturn xsi:type="xsd:string">#{token}</loginReturn>
    </ns1:loginResponse>
  </soapenv:Body>
</soapenv:Envelope>
XML
end

def login_error_response
  <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Body>
    <soapenv:Fault>
      <faultcode>soapenv:Server.userException</faultcode>
      <faultstring>com.atlassian.jira.rpc.exception.RemoteAuthenticationException: Invalid username or password.</faultstring>
      <detail>
        <com.atlassian.jira.rpc.exception.RemoteAuthenticationException
            xsi:type="ns1:RemoteAuthenticationException"
            xmlns:ns1="http://exception.rpc.jira.atlassian.com"/>
        <ns2:hostname xmlns:ns2="http://xml.apache.org/axis/">localhost</ns2:hostname>
      </detail>
    </soapenv:Fault>
  </soapenv:Body>
</soapenv:Envelope>
XML
end

def missing_issue_error
  <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Body>
    <soapenv:Fault>
      <faultcode>soapenv:Server.userException</faultcode>
      <faultstring>com.atlassian.jira.rpc.exception.RemotePermissionException: This issue does not exist or you don't have permission to view it.</faultstring>
      <detail>
        <com.atlassian.jira.rpc.exception.RemoteException
            xsi:type="ns1:RemotePermissionException"
            xmlns:ns1="http://exception.rpc.jira.atlassian.com"/>
        <ns2:hostname xmlns:ns2="http://xml.apache.org/axis/">localhost</ns2:hostname>
      </detail>
    </soapenv:Fault>
  </soapenv:Body>
</soapenv:Envelope>
XML
end

def miscellaneous_error
  <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Body>
    <soapenv:Fault>
      <faultcode>soapenv:Server.userException</faultcode>
      <faultstring>com.atlassian.jira.rpc.exception.RemoteException: !</faultstring>
      <detail>
        <com.atlassian.jira.rpc.exception.RemoteException
            xsi:type="ns1:RemoteException"
            xmlns:ns1="http://exception.rpc.jira.atlassian.com"/>
        <ns2:hostname xmlns:ns2="http://xml.apache.org/axis/">localhost</ns2:hostname>
      </detail>
    </soapenv:Fault>
  </soapenv:Body>
</soapenv:Envelope>
XML
end

def update_issue_response
  <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Body>
    <ns1:updateIssueResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://soap.rpc.jira.atlassian.com">
      <updateIssueReturn href="#id0"/>
    </ns1:updateIssueResponse>
    <multiRef id="id0" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns2:RemoteIssue" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns2="http://beans.soap.rpc.jira.atlassian.com">
      <affectsVersions soapenc:arrayType="ns2:RemoteVersion[0]" xsi:type="soapenc:Array"/>
      <assignee xsi:type="xsd:string">connector</assignee>
      <attachmentNames soapenc:arrayType="xsd:string[0]" xsi:type="soapenc:Array"/>
      <components soapenc:arrayType="ns2:RemoteComponent[0]" xsi:type="soapenc:Array"/>
      <created xsi:type="xsd:dateTime">2010-03-02T15:20:54.690Z</created>
      <customFieldValues soapenc:arrayType="ns2:RemoteCustomFieldValue[2]" xsi:type="soapenc:Array">
        <customFieldValues href="#id1"/>
        <customFieldValues href="#id2"/>
      </customFieldValues>
      <description xsi:type="xsd:string">DESC for Yet another user</description>
      <duedate xsi:type="xsd:dateTime">2010-03-26T00:00:00.000Z</duedate>
      <environment xsi:type="xsd:string">ENV for Yet another bug</environment>
      <fixVersions soapenc:arrayType="ns2:RemoteVersion[0]" xsi:type="soapenc:Array"/>
      <id xsi:type="xsd:string">10010</id>
      <key xsi:type="xsd:string">MITP-5</key>
      <priority xsi:type="xsd:string">4</priority>
      <project xsi:type="xsd:string">MITP</project>
      <reporter xsi:type="xsd:string">connector</reporter>
      <resolution xsi:type="xsd:string" xsi:nil="true"/>
      <status xsi:type="xsd:string">1</status>
      <summary xsi:type="xsd:string">Yet another bug</summary>
      <type xsi:type="xsd:string">1</type>
      <updated xsi:type="xsd:dateTime">2010-04-12T15:56:25.216Z</updated>
      <votes xsi:type="xsd:long">0</votes>
    </multiRef>
    <multiRef id="id1" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns3:RemoteCustomFieldValue" xmlns:ns3="http://beans.soap.rpc.jira.atlassian.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
      <customfieldId xsi:type="xsd:string">customfield_10000</customfieldId>
      <key xsi:type="xsd:string" xsi:nil="true"/>
      <values soapenc:arrayType="xsd:string[1]" xsi:type="soapenc:Array">
        <values xsi:type="xsd:string">http://localhost:8080/projects/test/cards/121</values>
      </values>
    </multiRef>
    <multiRef id="id2" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns3:RemoteCustomFieldValue" xmlns:ns3="http://beans.soap.rpc.jira.atlassian.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
      <customfieldId xsi:type="xsd:string">customfield_10001</customfieldId>
      <key xsi:type="xsd:string" xsi:nil="true"/>
      <values soapenc:arrayType="xsd:string[1]" xsi:type="soapenc:Array">
        <values xsi:type="xsd:string">Ready for QA</values>
      </values>
    </multiRef>
  </soapenv:Body>
</soapenv:Envelope>
XML
end

def get_available_actions_response id, name
  <<-XML
<?xml version="1.0" encoding="utf-8"?>
  <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <soapenv:Body>
      <ns1:getAvailableActionsResponse
          soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:ns1="http://soap.rpc.jira.atlassian.com">
        <getAvailableActionsReturn soapenc:arrayType="ns2:RemoteNamedObject[1]"
                                   xsi:type="soapenc:Array"
                                   xmlns:ns2="http://beans.soap.rpc.jira.atlassian.com"
                                   xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
          <getAvailableActionsReturn href="#id0"/>
        </getAvailableActionsReturn>
      </ns1:getAvailableActionsResponse>
      <multiRef id="id0" soapenc:root="0"
                         soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
                         xsi:type="ns3:RemoteNamedObject"
                         xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
                         xmlns:ns3="http://beans.soap.rpc.jira.atlassian.com">
        <id xsi:type="xsd:string">#{id}</id>
        <name xsi:type="xsd:string">#{name}</name>
      </multiRef>
    </soapenv:Body>
  </soapenv:Envelope>
XML
end

def get_no_available_actions_response
  <<-XML
<?xml version="1.0" encoding="utf-8"?>
  <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <soapenv:Body>
      <ns1:getAvailableActionsResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
                                       xmlns:ns1="http://soap.rpc.jira.atlassian.com">
        <getAvailableActionsReturn xsi:type="soapenc:Array"
                                   xsi:nil="true" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"/>
      </ns1:getAvailableActionsResponse>
    </soapenv:Body>
  </soapenv:Envelope>
XML
end

def progress_workflow_action_response
  <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Body>
    <ns1:progressWorkflowActionResponse
        soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
        xmlns:ns1="http://soap.rpc.jira.atlassian.com">
      <progressWorkflowActionReturn href="#id0"/>
    </ns1:progressWorkflowActionResponse>
    <multiRef id="id0" soapenc:root="0"
                       soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
                       xsi:type="ns2:RemoteIssue"
                       xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
                       xmlns:ns2="http://beans.soap.rpc.jira.atlassian.com">
      <affectsVersions soapenc:arrayType="ns2:RemoteVersion[0]" xsi:type="soapenc:Array"/>
      <assignee xsi:type="xsd:string">admin</assignee>
      <attachmentNames soapenc:arrayType="xsd:string[0]" xsi:type="soapenc:Array"/>
      <components soapenc:arrayType="ns2:RemoteComponent[0]" xsi:type="soapenc:Array"/>
      <created xsi:type="xsd:dateTime">2011-03-07T14:30:30.926Z</created>
      <customFieldValues soapenc:arrayType="ns2:RemoteCustomFieldValue[2]"
                         xsi:type="soapenc:Array">
        <customFieldValues href="#id1"/>
        <customFieldValues href="#id2"/>
      </customFieldValues>
      <description xsi:type="xsd:string" xsi:nil="true"/>
      <duedate xsi:type="xsd:dateTime" xsi:nil="true"/>
      <environment xsi:type="xsd:string" xsi:nil="true"/>
      <fixVersions soapenc:arrayType="ns2:RemoteVersion[0]" xsi:type="soapenc:Array"/>
      <id xsi:type="xsd:string">10000</id>
      <key xsi:type="xsd:string">MIRA-1</key>
      <priority xsi:type="xsd:string">3</priority>
      <project xsi:type="xsd:string">MIRA</project>
      <reporter xsi:type="xsd:string">admin</reporter>
      <resolution xsi:type="xsd:string" xsi:nil="true"/>
      <status xsi:type="xsd:string">5</status>
      <summary xsi:type="xsd:string">Where are my trousers?</summary>
      <type xsi:type="xsd:string">2</type>
      <updated xsi:type="xsd:dateTime">2011-03-09T11:49:15.831Z</updated>
      <votes xsi:type="xsd:long">0</votes>
    </multiRef>
    <multiRef id="id2" soapenc:root="0"
                       soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
                       xsi:type="ns3:RemoteCustomFieldValue"
                       xmlns:ns3="http://beans.soap.rpc.jira.atlassian.com"
                       xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
      <customfieldId xsi:type="xsd:string">customfield_10001</customfieldId>
      <key xsi:type="xsd:string" xsi:nil="true"/>
      <values soapenc:arrayType="xsd:string[1]" xsi:type="soapenc:Array">
        <values xsi:type="xsd:string">
          http://localhost:8080/projects/mingle_jira_connector/cards/130
        </values>
      </values>
    </multiRef>
    <multiRef id="id1" soapenc:root="0"
              soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
              xsi:type="ns4:RemoteCustomFieldValue"
              xmlns:ns4="http://beans.soap.rpc.jira.atlassian.com"
              xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
      <customfieldId xsi:type="xsd:string">customfield_10000</customfieldId>
      <key xsi:type="xsd:string" xsi:nil="true"/>
      <values soapenc:arrayType="xsd:string[1]" xsi:type="soapenc:Array">
        <values xsi:type="xsd:string">value from soap</values>
      </values>
    </multiRef>
  </soapenv:Body>
</soapenv:Envelope>
XML
end
