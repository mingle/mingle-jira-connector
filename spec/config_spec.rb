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
load_files 'config'
include MingleConnector

describe Config do
  def config() MingleConnector::Config.new :spec=>spec, :reader=>reader end
  def spec() @spec ||= {:mingle=>[{:name=>:host}, {:name=>:port}]} end
  def reader() @reader ||= HashConfigReader.new data end
  def data() @data ||= {} end

  it "doesn't read the data when it hasn't been asked for a value" do
    reader.should_not_receive :read
    config
  end

  it "contains an entry it was initialized with" do
    @data = {'mingle'=>{'host'=>'localhost'}}
    config.section(:mingle)[:host].should =='localhost'
  end

  it "raises an exception if asked for an unknown entry" do
    @data = {'mingle'=>{}}
    lambda { config.section(:mingle)[:unknown] }.
      should raise_error(MingleConnector::Config::UnknownEntry)
  end

  describe "validating" do
    it "passes if all entries are present" do
      @spec = {:mingle=>[:name=>:host]}
      @data = {'mingle'=>{'host'=>'localhost'}}
      lambda { config.validate }.should_not raise_error MingleConnector::Config::InvalidConfig
    end

    it "fails if a entry is missing" do
      @spec = {:present=>[:name=>:missing]}
      @data = {'present'=>{}}
      config.should have_missing_config_validation_error :present, 'missing'
    end

    it "fails if an entry from the nested section is missing" do
      @spec = {
        :mingle=>[
                  {:name=>:credentials, :spec=>[{:name=>:user}]},
                  ]
      }
      @data = {'mingle'=>{'credentials'=>{}}}
      config.should have_missing_config_validation_error :credentials, 'user'
    end

    it "fails is a section array has nothing in it" do
      @spec = {
        :mingle=>[
                  [{:name=>:projects, :spec=>[{:name=>:identifier}]}],
                  ]
      }
      @data = {'mingle'=>{'projects'=>[]}}
      config.should have_missing_config_validation_error :mingle, 'projects'
    end

    it "fails if a section array is missing" do
      @spec = {
        :mingle=>[
                  [{:name=>:projects, :spec=>[{:name=>:identifier}]}],
                  ]
      }
      @data = {'mingle'=>{}}
      config.should have_missing_config_validation_error :mingle, 'projects'
    end

    it "fails if an entry in a section array is invalid" do
      @spec = {
        :mingle=>[
                  [{:name=>:projects, :spec=>[{:name=>:identifier}]}],
                  ]
      }
      @data = {'mingle'=>{'projects'=>[{}]}}
      config.should have_missing_config_validation_error 'projects', 'identifier'
    end

    it "fails if the entire section is missing" do
      @spec = {:section=>[:name=>:entry]}
      @data = {}
      config.should have_missing_config_validation_error :section, 'entry'
    end

    it "doesn't fail if an optional entry is missing" do
      @spec = {:present=>[:name=>:something, :optional=>true]}
      @data = {'present'=>{}}
      lambda { config.validate }.should_not raise_error MingleConnector::Config::InvalidConfig
    end

    it "doesn't fail if an optional within a nested section is missing" do
      @spec = {
        :mingle=>[
                  {:name=>:credentials, :spec=>[{:name=>:user, :optional=>true}]},
                  ]
      }
      @data = {'mingle'=>{'credentials'=>{}}}
      lambda { config.validate }.should_not raise_error MingleConnector::Config::InvalidConfig
    end

    it "fails if an unexpected entry is encountered" do
      @spec = {:present=>[]}
      @data = {'present'=>{'unexpected'=>''}}
      config.should have_unexpected_config_validation_error :present, 'unexpected'
    end

    it "fails if an entry from the nested section is unexpected" do
      @spec = {
        :mingle=>[
                  {:name=>:credentials, :spec=>[]},
                  ]
      }
      @data = {'mingle'=>{'credentials'=>{'user'=>'mira'}}}
      config.should have_unexpected_config_validation_error :credentials, 'user'
    end

    context "multiple types of error" do
      before do
        @spec = {:present=>[:name => :missing]};
        @data = {'present'=>{'unexpected' => ''}}
      end

      it "reports missing" do
        config.should have_missing_config_validation_error :present, 'missing'
      end

      it "reports unexpected" do
        config.should have_unexpected_config_validation_error :present, 'unexpected'
      end
    end

    context "nested sections with multiple types of error" do
      before do
        @spec = {
          :mingle=>[
                    {:name=>:credentials, :spec=>[{:name=>:password}]},
                   ]
        }
        @data = {'mingle'=>{'credentials'=>{'user'=>'mira'}}}
      end

      it "reports missing" do
        config.should have_missing_config_validation_error :credentials, 'password'
      end

      it "reports unexpected" do
        config.should have_unexpected_config_validation_error :credentials, 'user'
      end
    end
  end

  describe "defaulting" do
    before { @spec = {:present=>[:name=>:defaulted, :default=>'default']} }

    it "doesn't mind if a defaulted entry is missing" do
      @data = {'present'=>{}}
      lambda { config.validate }.should_not raise_error MingleConnector::Config::InvalidConfig
    end

    it "provides the default if the value is missing" do
      @data = {'present'=>{}}
      config.section(:present)[:defaulted].should =='default'
    end

    it "ignores the default if a value is provided" do
      @data = {'present'=>{'defaulted'=>'value'}}
      config.section(:present)[:defaulted].should =='value'
    end

    it "provides defaults for entries in nested sections" do
      @spec = {
        :mingle=>[
                  {:name=>:credentials, :spec=>[{:name=>:user, :default=>'mira'}]},
                 ]
      }
      @data = {'mingle'=>{'credentials'=>{}}}
      config.section(:mingle)[:credentials][:user].should == 'mira'
    end
  end

  describe "optional entries" do
    before { @spec = {:present=>[:name=>:something, :optional=>true]} }
    it "defaults value to nil" do
      @data = {'present'=>{}}
      config.section(:present)[:something].should be_nil
    end
    it "returns a value provided" do
      @data = {'present'=>{'something'=>'foo'}}
      config.section(:present)[:something].should == 'foo'
    end
  end

  describe "alias" do
    it "uses the value from the alias" do
      @spec = {:section=>[{:name=>:with_alias, :alias=>:the_alias}]}
      @data = {'section'=>{'the_alias'=>'value'}}
      config.section(:section)[:with_alias].should == 'value'
    end

    it "uses the value of the alias in preference to a default" do
      @spec = {:section=>[{:name=>:with_alias, :alias=>:the_alias, :default=>'the-default'}]}
      @data = {'section'=>{'the_alias'=>'value'}}
      config.section(:section)[:with_alias].should == 'value'
    end

    it "uses the value from the alias in a nested section" do
      @spec = {
          :mingle=>[
                    {:name=>:credentials, :spec=>[{:name=>:user, :alias=>:username}]},
                   ]
        }
      @data = {'mingle'=>{'credentials'=>{'username'=>'mira'}}}
      config.section(:mingle)[:credentials][:user].should == 'mira'
    end

    it "works with section arrays" do
      @spec = {
        :mingle=>[
                  [{:name=>:projects, :alias=>:project, :spec=>[{:name=>:identifier}]}],
                 ]
      }
      @data = {'mingle'=>{'project'=>[{'identifier'=>'mira'}]}}
      config.section(:mingle)[:projects].first[:identifier].should == 'mira'
    end

    describe "validation" do
      it "is valid if only the alias value is provided" do
        @spec = {:section=>[{:name=>:with_alias, :alias=>:the_alias}]}
        @data = {'section'=>{'the_alias'=>'value'}}
        lambda { config.validate}.should_not raise_error(MingleConnector::Config::InvalidConfig)
      end

      it "fails if both the entry and its alias are provided" do
        @spec = {:section=>[{:name=>:with_alias, :alias=>:the_alias}]}
        @data = {'section'=>{'the_alias'=>'value', 'with_alias'=>'another_value'}}
        config.should have_duplicate_config_validation_error :section, 'with_alias'
      end
    end
  end

  describe "conversion" do
    it "converts using the lambda" do
      @spec = {:section=>[{:name=>:convert_me, :converter=>lambda { |v| "converted #{v}"}}]}
      @data = {'section'=>{'convert_me'=>'value'}}

      config.section(:section)[:convert_me].should == 'converted value'
    end

    it "converts the default if that is used" do
      @spec = {:section=>[{:name=>:convert_me, :default=>'default value',
                            :converter=>lambda { |v| "converted #{v}"}}]}
      @data = {}

      config.section(:section)[:convert_me].should == 'converted default value'
    end
  end

  describe "nesting" do
    it "gets values from the nested section" do
      @spec = {
        :mingle=>[
                  {:name=>:credentials, :spec=>[{:name=>:user}]},
                  ]
      }
      @data = {'mingle'=>{'credentials'=>{'user'=>'mira'}}}
      config.section(:mingle)[:credentials][:user].should == 'mira'
    end

    it "gets values from nested sections which are lists" do
      @spec = {
        :mingle=>[
                  [{:name=>:projects, :spec=>[{:name=>:identifier}]}],
                  ]
      }
      @data = {'mingle'=>{'projects'=>[{'identifier'=>'PROJ1'}, {'identifier'=>'PROJ2'}]}}
      config.section(:mingle)[:projects].first[:identifier].should == 'PROJ1'
      config.section(:mingle)[:projects].last[:identifier].should == 'PROJ2'
    end
  end
end

describe MingleConnector::Config::InvalidConfig do
  it "tells the errors to log themselves" do
    logger = Object.new
    errors = [mock('error1'), mock('error2')]
    errors.each { |e| e.should_receive(:log).with(logger) }
    MingleConnector::Config::InvalidConfig.new(errors).log(logger)
  end
end

[[:have_missing_config_validation_error, :missing_config],
 [:have_unexpected_config_validation_error, :unexpected_config],
 [:have_duplicate_config_validation_error, :duplicate_config]].each do |matcher, method|
  Spec::Matchers.define matcher do |section, entry|
    match do |config|
      @logger = RecordingLogger.new(method)
      begin
        config.validate
      rescue MingleConnector::Config::InvalidConfig => e
        e.log @logger
      end
      @logger.section == section && @logger.entry == entry
    end

    failure_message_for_should do |proc|
      "Expected logger.#{method} to be called with #{section}, #{entry} but #{@logger.actual}"
    end
  end
end

class RecordingLogger
  attr_reader :section, :entry
  def initialize log
    @log = log
  end
  def method_missing name, *args
    if name == @log
      @called = true
      (@section, @entry) = *args
    end
  end
  def actual
    @called or return "it wasn't called"
    "it was called with #{@section}, #{@entry}"
  end
end
