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
load_files 'web_client'
include MingleConnector

describe AuthenticatingWebClient do
  before do
    strict_order_mock :wrapped
    @client = AuthenticatingWebClient.new('username', 'password').
      decorating @wrapped
  end
  describe "post" do
    it "authenticates before" do
      @wrapped.expect.authenticate 'username', 'password'
      @wrapped.expect.post 'url', 'params'
      @client.post 'url', 'params'
    end
    it "returns the response" do
      @wrapped.stub! :authenticate
      @wrapped.stub!(:post).and_return 'foo'
      @client.post(nil, nil).should == 'foo'
    end
  end
  describe "get" do
    it "authenticates before" do
      @wrapped.expect.authenticate 'username', 'password'
      @wrapped.expect.get 'url'
      @client.get 'url'
    end
    it "returns the response" do
      @wrapped.stub! :authenticate
      @wrapped.stub!(:get).and_return 'foo'
      @client.get(nil).should == 'foo'
    end
  end
end

describe LoggingWebClient do
  before do
    strict_order_mocks :logger, :wrapped
    @logging_web_client = LoggingWebClient.new(@logger).decorating @wrapped
  end

  it "should log before and after a get request is invoked" do
    @logger.expect.webclient_get_before('http://localhost')
    @wrapped.expect.get('http://localhost').and_return('the-response')
    @logger.expect.webclient_get_after('the-response')

    @logging_web_client.get('http://localhost').should == 'the-response'
  end

  it "should log before and after a post request is invoked" do
    @logger.expect.webclient_post_before('http://localhost', 'params')
    @wrapped.expect.post('http://localhost', 'params').and_return('the-response')
    @logger.expect.webclient_post_after('the-response')

    @logging_web_client.post('http://localhost', 'params').should == 'the-response'
  end
end

describe ResponseValidatingWebClient do
  def response() @response ||= WebClient::Response.new(@status, 'body', nil) end
  def wrapped() @wrapped ||= StubWebClient.new(response) end
  def web_client() ResponseValidatingWebClient.new.decorating(wrapped) end

  {
    :get=>['http://foo'],
    :post=>['http://foo', 'the-params']
  }.each do |method, params|
    describe method do
      describe "simple decoration" do
        before { @status = 200 }
        it "asks the wrapped to get the url" do
          wrapped.should_receive(method).with(*params).and_return(response)
          web_client.send(method, *params)
        end

        it "returns the response" do
          web_client.send(method, *params).should ==response
        end
      end

      [400, 401, 403, 404, 500].each do |status|
        context "#{status} response" do
          before { @status = status }
          it "raises an HttpResponseError" do
            lambda { web_client.send(method, *params) }.
              should(raise_response_error status, response, params)
          end
        end
      end

      it "distinguishes 404 responses" do
        @status = 404
        lambda { web_client.send(method, *params) }.should raise_error(HttpNotFoundError)
      end

      [200, 201].each do |status|
        context "#{status} response" do
          before { @status = status }
          it "doesn't raise an exception" do
            lambda { web_client.send(method, *params) }.should_not raise_error
          end
        end
      end

      it "treats an unknown status code as an error" do
        @status = 999
        lambda { web_client.send(method, *params) }.should raise_error(HttpResponseError)
      end

      def raise_response_error status, response, params
        raise_error(HttpResponseError) do |e|
          e.status.should == status
          e.url.should == params[0]
          e.response_body.should == response.body
        end        
      end
    end
  end
end
