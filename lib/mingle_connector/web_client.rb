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
require File.dirname(__FILE__) + '/../../vendor/jars/commons-httpclient-3.0.1.jar'
require File.dirname(__FILE__) + '/../../vendor/jars/commons-logging-1.0.3.jar'
require File.dirname(__FILE__) + '/../../vendor/jars/commons-codec-1.2.jar'
require File.dirname(__FILE__)+'/utils'

module MingleConnector
  class WebClient
    include Utils
    def initialize()
      turn_off_logging_for('org.apache.commons.httpclient', 'httpclient')
      @client = org.apache.commons.httpclient.HttpClient.new
    end

    def post url, params
      request = org.apache.commons.httpclient.methods.PostMethod.new(url)
      request.set_request_body(convert_params(params))
      execute(request)
      response_from request
    end

    def get url
      request = org.apache.commons.httpclient.methods.GetMethod.new(url)
      execute(request)
      response_from request
    end

    def authenticate username, password
        @client.get_state.set_credentials(nil, nil,
                                          org.apache.commons.httpclient.UsernamePasswordCredentials.new(username, password))
    end

    class Response
      attr_reader :status, :body, :headers
      def initialize status, body, headers
        @status = status; @body = body; @headers = headers
      end
    end

    private
    def execute request
      @client.execute_method(request)
    end

    def convert_params params
      params.map { |k, v| org.apache.commons.httpclient.NameValuePair.new k, v }.to_java(org.apache.commons.httpclient.NameValuePair)
    end

    def response_from request
      headers = request.get_response_headers.
        inject({}) {|acc, header| acc.merge header.get_name=>header.get_value }
      Response.new request.get_status_code, request.get_response_body_as_string, headers
    end
  end

  class AuthenticatingWebClient
    include Decorator
    def initialize username, password
      @username = username; @password = password
    end

    def post url, params
      authenticate
      wrapped.post url, params
    end

    def get url
      authenticate
      wrapped.get url
    end

    private
    def authenticate
      wrapped.authenticate @username, @password
    end
  end

  class LoggingWebClient
    include Decorator
    def initialize logger
      @logger = logger
    end

    def get url
      @logger.webclient_get_before url
      response = wrapped.get url
      @logger.webclient_get_after response
      response
    end

    def post url, params
      @logger.webclient_post_before(url, params)
      response = wrapped.post url, params
      @logger.webclient_post_after(response)
      response
    end
  end

  class ResponseValidatingWebClient
    include Decorator

    def get url
      checking_response(url) { wrapped.get(url) }
    end

    def post url, params
      checking_response(url) { wrapped.post(url, params) }
    end

    private
    def checking_response url
      response = yield
      success?(response) or raise error_for(url, response)
      response
    end

    def success? response
      [200,201].include?(response.status)
    end

    def error_for url, response
      error = not_found?(response) ? HttpNotFoundError : HttpResponseError
      error.new(response.status, url, response.body)
    end

    def not_found? response
      response.status == 404
    end
  end

  class HttpResponseError < Exception
    attr_reader :status, :url, :response_body
    def initialize status, url, response_body
      @status = status
      @url = url
      @response_body = response_body
    end
  end

  class HttpNotFoundError < HttpResponseError ; end
end
