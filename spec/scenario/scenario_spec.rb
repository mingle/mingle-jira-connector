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
require 'java'

require File.dirname(__FILE__)+'/../shared/http_server'
require File.dirname(__FILE__)+'/../spec_helper'
require File.dirname(__FILE__)+'/../shared/jira_server'
load_file 'mingle_connector'

require 'tmp/build/mingle-listener.jar'
require 'tmp/build/fake-jira.jar'

require 'observer'
require 'forwardable'
require 'java/lib/commons-httpclient-3.0.1.jar'
require 'java/lib/commons-codec-1.2.jar'
require 'java/lib/commons-logging-1.0.3.jar'

describe 'Scenarios' do
  it "issues are passed to dev and the dev team resolves some of them" do
    opie.raises_a_feature_request('Better rendering of fonts', :project=>mconn,
                                  :description=>"The fonts are rendered horribly!Please fix 'em.")
    opie.passes_feature_to_dev 'Better rendering of fonts'

    opie.raises_a_bug 'Login button is missing', :project=>qconn
    opie.passes_feature_to_dev 'Login button is missing'

    opie.checks_that_issue_passed_to_dev 'Better rendering of fonts'
    opie.checks_that_issue_passed_to_dev 'Login button is missing'

    opie.raises_a_feature_request 'Comment words blacklist', :project=>web
    opie.passes_feature_to_dev 'Comment words blacklist'
    opie.checks_that_issue_passed_to_dev 'Comment words blacklist'

    dev.starts_developing 'Better rendering of fonts'
    dev.starts_developing 'Comment words blacklist'
    dev.starts_developing 'Login button is missing'
    timer.triggers
    jira.issue('Better rendering of fonts').should have_development_status('In Progress')
    jira.issue('Comment words blacklist').should have_development_status('In Progress')
    jira.issue('Login button is missing').should have_development_status('In Progress')

    dev.finishes 'Better rendering of fonts'
    dev.finishes 'Login button is missing'
    timer.triggers

    jira.issue('Better rendering of fonts').should have_status('Resolved')
    jira.issue('Comment words blacklist').should have_status('In Development')
    jira.issue('Login button is missing').should have_status('Resolved')
  end

  before do
    MingleConnector::Logging.log_to_stdout
    mingle.start
    jira.start
    touch_the_bookmark_file_so_we_dont_operate_in_first_time_mode
    pid_file_exists and raise "found an old pid file"

  end

  after { mingle.stop }
  after { jira.stop }
  after { delete(File.dirname(__FILE__)+'/../../mingle-jira-connector.log') }
  after { delete(File.dirname(__FILE__)+'/../../exceptions.log') }
  after { delete(bookmark_file) }
  after(:all) { org.apache.log4j.LogManager.shutdown }

  def delete file
    File.exists?(file) && File.delete(file)
  end
  def touch_the_bookmark_file_so_we_dont_operate_in_first_time_mode
    bookmark = MingleConnector::FileSystemMultiProjectBookmarks.new(Void.new)
    bookmark.mark_read(struct(:ident=>'from-last-run', :project=>'the-project'))
    bookmark.mark_read(struct(:ident=>'from-last-run', :project=>'web-project'))
  end
  def bookmark_file() File.dirname(__FILE__)+'/../../bookmark' end
  def pid_file_exists() File.exists?(MingleConnector::Platform.new.pid_file_path) end

  def jira
    @jira ||= JiraSimulator.new
  end

  def qconn() {:key=>'QCONN', :name=>'Quality Connector Project'} end
  def mconn() {:key=>'MCONN', :name=>'Mingle Connector Project'} end
  def web() {:key=>'WEB', :name=>'Webmaster Project'} end

  def opie
    Opie.new(jira, self)
  end

  def dev
    Dev.new mingle
  end

  def timer
    Timer.new
  end

  def mingle
    @mingle ||= MingleSimulator.new
  end

  def of_card name
    card = mingle.card_with(:name=>name)
    "http://localhost:3080/projects/#{card.project}/cards/#{card.number}"
  end

  def IN_PROGRESS
    begin
      yield
      raise "Unexpected success"
    rescue Spec::Expectations::ExpectationNotMetError
    end
  end
end

class JiraSimulator
  include MingleConnector::Utils
  include com.thoughtworks.mingleconnector.JiraSimulator

  def initialize
    properties = com.thoughtworks.mingleconnector.Config::Property
    com.atlassian.jira.ComponentManager.jira(self)
    turn_off_logging_for('org.apache.commons.httpclient', 'mingle-connector', 'httpclient')
    @listener = com.thoughtworks.mingleconnector.Listener.new
    @listener.init('Mingle server'=>'http://localhost:3080',
                   'Project mappings'=>'MCONN=>the-project, WEB=>web-project, QCONN=>the-project',
                   'Handover statuses'=>'MCONN=>In QA, WEB=>In Development, QCONN=>In Development',
                   'Mingle user'=>'connector',
                   'Mingle password'=>'password',
                   properties::TYPES.to_s=>'Feature Request=>Story',
                   properties::PROPERTIES.to_s=>'Project=>Tool, Created=>Issue Raised, Priority=>Priority, Assignee=>Support Owner, Reporter=> Support Reporter, Due Date=>Due Date',
                   properties::PRIORITIES.to_s=>'Critical=>High, Very Important=>Medium, Irrelevant=>Low',
                   properties::INITIAL_CARD_VALUES.to_s=>'Status=>New, Customer=>Support')
  end

  def start
    @server = JiraHttpServer.new(3090)
    @server.start
  end

  def stop
    @server.stop
  end

  def has_an_issue(details, type)
    details[:type] = type
    issue = @server.add_issue(details)
    issue.add_observer(self)
    trigger_listener issue # our listener needs to be able to handle
                           # issue-creation events
  end
  def has_a_feature_request(issue)
    has_an_issue(issue, "Feature Request")
  end
  def has_a_bug(issue)
    has_an_issue(issue, "Bug")
  end

  def issue(summary) issue_with(:summary=>summary) end

  def issue_with condition
    key, summary = condition[:key], condition[:summary]
    key and return @server.issue_with_key(key)
    summary and return @server.issue_with_summary(summary)
  end

  def update_property issue_key, property_name, value
    issue_with(:key=>issue_key)[property_name] = value
  end

  def base_url
    'http://localhost:3090'
  end

  # This inconveniently-named method is part of the Observable protocol
  def update issue, property, value
    trigger_listener(issue, [org.ofbiz.core.entity.GenericEntity.new(property, value)])
  end

  private
  def trigger_listener issue, changes=[]
    jira_issue = JiraIssue.new(issue)
    event = com.atlassian.jira.event.issue.IssueEvent.new(jira_issue, changes)
    @listener.workflowEvent(event)
  end

  class JiraIssue
    include com.atlassian.jira.issue.Issue
    def initialize(issue) @issue = issue end
    def get_key() @issue.key end
    def get_issue_type_object()
      com.atlassian.jira.issue.issuetype.IssueTypeImpl.new(@issue.type)
    end
    def get_project_object()
      JiraProject.new @issue.project
    end
    def get_summary() @issue.summary end
    def get_description() @issue.description end
    def get_priority_object() return JiraPriority.new @issue end
    def get_created() java_date(@issue.created) end
    def get_due_date() java_date(@issue.due_date) end
    def get_assignee() com.opensymphony.user.User.new(@issue.assignee) end
    def get_reporter() com.opensymphony.user.User.new(@issue.reporter) end

    private
    def java_date(date) java.sql.Timestamp.new(date.to_i * 1000) end

    class JiraPriority
      def initialize(issue) @issue = issue end
      def get_name() @issue.priority end
    end

    class JiraProject
      def initialize project
        @project = project
      end

      def get_key()
        @project[:key]
      end

      def get_name()
        @project[:name]
      end
    end
  end
end

class AtomFeed
  def initialize(project) @project=project end

  def entries() @entries ||= [] end

  def xml
    "<feed>#{entries.reverse.join}</feed>"
  end

  def add_event number, property, value
    id = rand(1000)
    entries << <<-ENTRY
      <entry>
        <id>#{id}</id>
        <link rel='http://www.thoughtworks-studios.com/ns/mingle#event-source' type='application/vnd.mingle+xml' href='http://localhost:3080/api/v2/projects/#{@project}/cards/#{number}.xml' />
        <change type='property-change'>
          <property_definition>
             <name>#{property}</name>
          </property_definition>
          <new_value>#{value}</new_value>
        </change>
      </entry>
    ENTRY
  end
end

class FeedCollection
  def initialize() @feeds = {} end
  def [] project
    @feeds[project] or @feeds[project] = AtomFeed.new(project)
  end
end

class MingleSimulator
  extend Forwardable
  include Spec::Matchers
  def initialize
    @feeds = FeedCollection.new
    @cards = []
    @server = DispatchingServer.new(Commands.new(@feeds, self), true)
  end
  def_delegators :@server, :start, :stop

  def add_card(project, card)
    mingle_card = Card.new(project, card)
    mingle_card.add_observer self
    @cards.push(mingle_card)
    mingle_card
  end
  alias :has_card :add_card

  def cards
    @cards
  end

  def update project, number, prop_name, new_value
    @feeds[project].add_event number, prop_name, new_value
  end

  def card_with condition
    cards.find do |card|
      card.properties[:name] == condition[:name]
    end
  end

  def card_numbered number, project
    @cards.find { |c| c.number == number && c.project == project }
  end

  private
  class Card
    include Observable
    attr_reader :properties
    def initialize project, properties
      @project = project
      @properties = properties
      @number = rand(1000).to_s
    end

    def number() @number end
    def name() @properties[:name] end
    def project() @project end
    def description() @properties[:description] end
    def type() @properties[:type] end

    def set_property param
      changed
      @properties.merge! param
      notify_observers project, number, param.keys.first, param.values.first
    end

    def xml
      property_xml = @properties.map { |name, value|
        <<-XML
          <property>
            <name>#{name}</name>
            <value>#{value}</value>
          </property>
        XML
      }.join
      <<-XML
        <card>
          <number>#{@number}</number>
          <name>#{name}</name>
          <properties type="array">
            #{property_xml}
          </properties>
        </card>
      XML
    end

    def inspect
      {:number => number, :name => name, :type => type, :description => description }.inspect
    end
  end

  class Commands
    def initialize feeds, mingle
      @feeds, @mingle = feeds, mingle
    end

    def handlers
      [{:resource=>'cards', :method=>'POST', :action=>:create_card},
       {:resource=>"projects", :method=>'GET', :action=>:get_projects},
       {:resource=>"events", :method=>'GET', :action=>:get_events_feed},
       {:resource=>/\d+/, :method=>'GET', :action=>:get_card_for}]
    end

    def create_card request
      card_details = extract_card_details_from(request)
      properties = extract_properties_from(request)
      project = request.getRequestURI.split('/')[-2]
      card = @mingle.add_card(project, card_details.merge(properties))

      path = request.getRequestURI.split(".xml")[0]

      { :status => javax.servlet.http.HttpServletResponse.SC_CREATED,
        :location => "http://localhost:3080#{path}/#{card.number}.xml" }
    end

    def get_projects request
      {:result => "<projects/>"}
    end

    def get_events_feed request
      project = request.getRequestURI.split('/')[-3]
      raise "Blank project" if project == ''
      { :result => @feeds[project].xml }
    end

    def get_card_for request
      uri = request.getRequestURI
      card_number = File.basename(uri).split(".xml")[0]
      project = uri.split('/')[-3]
      {
        :result => @mingle.card_numbered(card_number, project).xml
      }
    end

    private
    def extract_card_details_from request
      {:name => request.getParameterMap['card[name]'].first,
        :type => request.getParameterMap['card[card_type_name]'].first,
        :description => request.getParameterMap['card[description]'].first}
    end

    def extract_properties_from request
      properties = {}
      property_names = request.getParameterMap['card[properties][][name]']
      if property_names
        property_values = request.getParameterMap['card[properties][][value]']
        property_names.each_with_index do |name, i|
          value = property_values[i]
          properties[name] = value
        end
      end
      properties
    end
  end
end

class Opie
  def initialize(jira, spec) @jira, @spec = jira, spec end

  def raises_a_bug summary, opts
    @jira.has_a_bug(:project=>opts[:project], :summary => summary, :status => 'Open',
                    :description=>opts[:description], :priority=>'Critical',
                    :assignee=>'Oscar Opie', :reporter=>'Charlie Client', :due_date=>Time.utc(2000, 'jan', 1))
  end

  def raises_a_feature_request summary, opts
    @jira.has_a_feature_request(:project=>opts[:project], :summary=>summary, :status=>'Open',
                                :description=>opts[:description], :priority=>'Very Important',
                                :assignee=>'Oscar Opie', :reporter=>'Charlie Client', :due_date=>Time.utc(1975, 'jun', 30))
  end

  def starts_progress summary
    update_status(summary, 'In Progress')
  end
  def passes_bug_to_dev(summary)
    update_status(summary, handover_status(summary))
  end
  alias :passes_feature_to_dev :passes_bug_to_dev

  def checks_that_issue_passed_to_dev summary
    issue = @jira.issue(summary)

    @spec.mingle.should @spec.have_card(:name => issue.summary, :type => card_type(issue),
                                        :description => description(issue), 'Status'=>'New',
                                        'Tool'=>issue.project[:name],
                                        'Issue Raised'=>issue.created.strftime('%d %b %Y'),
                                        'Priority'=>priority(issue),
                                        'Support Owner'=>issue.assignee,
                                        'Support Reporter'=>issue.reporter,
                                        'Due Date'=>issue.due_date.strftime('%d %b %Y'),
                                        'Customer'=>'Support')
    issue.should @spec.have_mingle_card(@spec.of_card(summary))
  end

  private
  def update_status summary, status
    @jira.issue(summary)[:status] = status
  end

  def handover_status summary
    statuses[@jira.issue(summary).project[:key]]
  end

  def description issue
    <<-DESCRIPTION
This card was created from an issue in JIRA: #{@jira.base_url}/browse/#{issue.key}

#{issue.description}
DESCRIPTION
  end

  def card_type issue
    {'Feature Request'=>'Story', 'Bug'=>'Bug'}[issue.type]
  end

  def priority issue
    {'Feature Request'=>'Medium', 'Bug'=>'High'}[issue.type]
  end

  def statuses
    {'MCONN' => 'In QA', 'QCONN' => 'In Development', 'WEB'=>'In Development'}
  end
end

class Dev
  def initialize mingle
    @mingle = mingle
  end
  def starts_developing name
    card = @mingle.card_with(:name => name)
    card.set_property(status_property(card) => 'In Progress')
  end
  def finishes name
    card = @mingle.card_with(:name => name)
    card.set_property(status_property(card) => done_status(card))
  end

  private
  def statuses card
    return {:name=>'Status', :done=>'Done' } if card.project == 'web-project'
    {'Story'=>{:name=>'Story Status', :done=>'Signed Off'},
      'Bug'=>{:name=>'Defect Status', :done=>'Fixed'}}[card.type]
  end

  def status_property(card) statuses(card)[:name] end
  def done_status(card) statuses(card)[:done] end
end

class Timer
  def triggers
    MingleConnector::run MingleConnector::YamlConfigReader.new config
  end
end

def config
<<YAML
mingle:
  baseurl: 'http://localhost:3080'
  user: 'connector'
  password: 'password'
  projects:
  - identifier: 'the-project'
    status_properties:
      Defect Status: 'Fixed'
      Story Status: 'Signed Off'
  - identifier: 'web-project'
jira:
  baseurl: 'http://localhost:3090'
  user: 'connector'
  password: 'password'
  mingle_dev_status_field: '10001'
  transitions:
     QCONN: 'Development Complete'
     MCONN: 'QA Complete'
logging:
  level: 'ERROR'
YAML
end

Spec::Matchers.define :have_card do |expected|
  match do |mingle|
    matching_cards_in(mingle, expected).length == 1
  end

  failure_message_for_should do |mingle|
    card = mingle.cards.find { |c| c.properties[:name]==expected[:name] }
    if !card
      "could not find card with name #{expected[:name]}"
    else
      wrong = expected.keys.reject { |property| expected[property] == card.properties[property] }
      actual_properties = card.properties.select { |p, v| wrong.include? p }
      expected_properties = expected.select { |p, v| wrong.include? p }
      "expected '#{card.properties[:name]}' to have properties #{expected_properties.inspect} but it had #{actual_properties.inspect}"
    end
  end

  def matching_cards_in mingle, card
    mingle.cards.select { |c| card.keys.all? { |k| c.properties[k]==card[k] } }
  end
end

Spec::Matchers.define :have_mingle_card do |url|
  match do |issue|
    issue["Mingle Card"] == url
  end

  failure_message_for_should do |issue|
    "expected issue #{issue.key} to have Mingle card '#{url}', but it was '#{issue["Mingle Card"]}'"
  end
end

Spec::Matchers.define :have_development_status do |development_status|
  match do |issue|
    issue["customfield_10001"] == development_status
  end
end
