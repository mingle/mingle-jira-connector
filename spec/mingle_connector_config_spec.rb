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
require File.dirname(__FILE__)+'/spec_helper'
load_files 'mingle_connector'
include MingleConnector

describe "the config spec" do
  describe "mingle section" do
    it "exists" do
      MingleConnector::config.should have_key :mingle
    end

    [:baseurl, :user, :password, :projects].
      each do |entry|
      it "includes #{entry}" do
        MingleConnector::config[:mingle].should have_entry entry
      end
    end

    it "defaults jira_issue_key_property to 'JIRA issue'" do
      MingleConnector::config[:mingle].
        find { |e| e[:name]==:jira_issue_key_property unless e.is_a? Array }.
        should have_default 'JIRA issue'
    end

    describe "projects" do
      it "has an alias 'project'" do
        MingleConnector::config[:mingle].find { |e| e.is_a? Array and e.first[:name]==:projects}.
          first.should have_alias :project
      end

      it "defaults status_properties to Status=>Done" do
        details = minimal_config
        details['mingle']['projects'] = [{'identifier'=>'mira'}]
        config = MingleConnector::Config.new(:spec=>MingleConnector::config,
                                             :reader=>HashConfigReader.new(details))
        config.validate
        config.section(:mingle)[:projects].first[:status_properties]['Status'].should == 'Done'
      end
    end
  end

  describe "logging section" do
    it "exists" do
      MingleConnector::config.should have_key :logging
    end

    [:filename, :level].each do |entry|
      it "includes #{entry}" do
        MingleConnector::config[:logging].should have_entry entry
      end
    end

    it "defaults filename to mingle-jira-connector.log" do
      MingleConnector::config[:logging].find { |e| e[:name]==:filename}.
        should have_default 'mingle-jira-connector.log'
    end

    it "defaults level to WARN" do
      MingleConnector::config[:logging].find { |e| e[:name]==:level}.
        should have_default 'WARN'
    end
  end

  describe "jira section" do
    it "exists" do
      MingleConnector::config.should have_key :jira
    end

    [:baseurl, :user, :password, :mingle_dev_status_field, :transitions].each do |entry|
      it "include #{entry}" do
        MingleConnector::config[:jira].should have_entry entry
      end
    end

    it "makes development status field optional" do
      details = minimal_config
      config = MingleConnector::Config.new(:spec=>MingleConnector::config,
                                           :reader=>HashConfigReader.new(details))
      config.validate
      config.section(:jira)[:mingle_dev_status_field].should be_nil
    end
  end
end

def minimal_config
  {
    'mingle'=>{
      'baseurl'=>'',
      'user'=>'',
      'password'=>'',
      'projects'=>[{'identifier'=>'mira'}],
    },
    'jira'=>{
      'baseurl'=>'',
      'user'=>'',
      'password'=>'',
      'transitions'=>'',
    }
  }
end

Spec::Matchers.define :have_entry do |entry|
  match do |section|
    section.find do |e|
      if e.is_a? Array
        e.first[:name] == entry
      else
        e[:name]==entry
      end
    end
  end
end

Spec::Matchers.define :have_default do |default|
  match do |entry|
    entry[:default] == default
  end
end

Spec::Matchers.define :have_alias do |the_alias|
  match do |entry|
    entry[:alias] == the_alias
  end
end
