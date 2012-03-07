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
require 'base64'
require File.dirname(__FILE__)+'/../spec_helper'
require File.dirname(__FILE__)+'/../shared/http_server'
load_files 'web_client'
include MingleConnector

describe WebClient do
  before do
    @web = WebClient.new 
    @server = TestHttpServer.new 3080
    @server.start
  end
  after { @server.stop }

  describe 'post' do
    it "posts to the url" do
      @web.post 'http://localhost:3080/foo', {}
      @server.last['POST'].should =='/foo'
    end
    it "posts the parameters" do
      @web.post 'http://localhost:3080/', 'foo'=>'bar'
      @server.last_params.should =={'foo'=>'bar'}
    end
    it "authenticates" do
      @web.authenticate 'username', 'password'
      @web.post 'http://localhost:3080/auth', {}
      @server.last_credentials.should =='username:password'
    end
    it "returns the response status" do
      response = @web.post 'http://localhost:3080', {}
      response.status.should ==200
    end
    it "returns the response body" do
      response = @web.post 'http://localhost:3080', {}
      response.body.should =='the response'
    end
    it "returns the response headers" do
      response = @web.post 'http://localhost:3080', {}
      response.headers['foo'].should =='bar'
    end
  end

  describe 'get' do
    it "gets the url" do
      @web.get 'http://localhost:3080/foo'
      @server.last['GET'].should =='/foo'
    end
    it "authenticates" do
      @web.authenticate 'username', 'password'
      @web.get 'http://localhost:3080/auth'
      @server.last_credentials.should =='username:password'
    end
    it "returns the response status" do
      response = @web.get 'http://localhost:3080'
      response.status.should ==200
    end
    it "returns the response body" do
      response = @web.get 'http://localhost:3080'
      response.body.should =='the response'
    end
    it "returns the response headers" do
      response = @web.get 'http://localhost:3080'
      response.headers['foo'].should =='bar'
    end
  end
end

class TestHttpServer < HttpServer
  def last() @last ||= {} end
  attr_accessor :last_params, :last_credentials

  def handler
    Handler.new self
  end

  class Handler
    def initialize(server)
      @server = server
    end
    def handle request, response
      begin
        response.getWriter().print 'the response'
        response.setHeader 'foo', 'bar'

        @server.last[request.getMethod] = request.getPathInfo
        @server.last_params = request.getParameterMap.
          inject({}) { |acc, (key, value)| acc.merge key=>value.first }

        if request.getPathInfo == '/auth'
          do_auth request, response
        end
      rescue
        puts $!, $@
        raise
      end
    end

    private
    def do_auth request, response
      credentials = request.
        getHeader org.eclipse.jetty.http.HttpHeaders::AUTHORIZATION
      if not credentials
        response.
          setStatus javax.servlet.http.HttpServletResponse.SC_UNAUTHORIZED
        response.setHeader 'WWW-Authenticate', 'Basic realm="auth"'
      else
        @server.last_credentials = Base64.decode64 credentials.split[1]
      end
    end
  end
end
