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
require 'spec/lib/jetty-server-7.0.1.v20091125.jar'
require 'spec/lib/jetty-continuation-7.0.1.v20091125.jar'
require 'spec/lib/jetty-http-7.0.1.v20091125.jar'
require 'spec/lib/jetty-io-7.0.1.v20091125.jar'
require 'spec/lib/jetty-util-7.0.1.v20091125.jar'
require 'spec/lib/jetty-security-7.0.1.v20091125.jar'
require 'spec/lib/servlet-api-2.5.jar'
require File.dirname(__FILE__) + '/../spec_helper'
load_file 'utils'

class HttpServer
  def initialize port, auth=false
    @port, @auth = port, auth
  end

  def start
    turn_off_jetty_logging
    @server = org.eclipse.jetty.server.Server.new @port
    @server.setHandler build_handler
    @server.start
  end

  def stop
    @server.stop
    @server.join
  end

  private
  def build_handler
    h = DelegatingHandler.new.decorating(handler)
    @auth and h = add_auth(h)
    h
  end

  def turn_off_jetty_logging
    org.eclipse.jetty.util.log.Log.setLog QuietLogger.new
  end

  class QuietLogger
    include org.eclipse.jetty.util.log.Logger
    def isDebugEnabled() false end
    def warn(*args) end
    def debug(*args) end
    def info(*args) end
  end

  class DelegatingHandler < org.eclipse.jetty.server.handler.AbstractHandler
    include MingleConnector::Decorator
    def handle(target, baseRequest, request, response)
      wrapped.handle(request, response)
      baseRequest.setHandled(true)
    end
  end

  def add_auth handler
    auth_handler = org.eclipse.jetty.security.ConstraintSecurityHandler.new
    login_service = org.eclipse.jetty.security.HashLoginService.new('login', 'spec/data/jetty-security.properties')
    auth_handler.set_login_service(login_service)

    constraint = org.eclipse.jetty.http.security.Constraint.new
    constraint.setName(org.eclipse.jetty.http.security.Constraint.__BASIC_AUTH);;
    constraint.setRoles(["user"].to_java(:string));
    constraint.setAuthenticate(true);

    cm = org.eclipse.jetty.security.ConstraintMapping.new
    cm.setConstraint(constraint);
    cm.setPathSpec("/*");

    auth_handler.set_constraint_mappings([cm].to_java(org.eclipse.jetty.security.ConstraintMapping))
    auth_handler.set_handler(handler)
    auth_handler
  end
end

class DispatchingServer < HttpServer
  def initialize commands, auth
    super(3080, auth)
    @commands = commands
  end
  def handler() Handler.new(@commands) end

  class Handler
    def initialize(commands)
      @commands = commands
    end

    def handle(request, response)
      begin
        template = execute_handler(request)
      rescue
        send_error(response)
        raise
      end

      populate(response, template)
    end

    private
    def execute_handler request
      handler = @commands.handlers.find { |k, v| handles(request, k[:resource], k[:method]) }
      @commands.send(handler[:action], request)
    end

    def send_error response
      populate(response, {:status=>javax.servlet.http.HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                 :result=>$!.inspect})
      puts $!.inspect
    end

    def populate response, template
      template[:location] and response.setHeader('Location', template[:location])
      template[:result] and response.getWriter().println(template[:result])
      status = template[:status] || javax.servlet.http.HttpServletResponse.SC_OK
      response.setStatus status
    end

    def resource_of request
      File.basename(request.getRequestURI).split(".xml")[0]
    end

    def handles request, resource, method
      request.getMethod == method && resource_of(request).match(resource)
    end
  end
end
