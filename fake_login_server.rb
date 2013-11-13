require 'sinatra'
require 'restclient'
require 'yajl'
require 'yajl/json_gem'
require 'logger'
require 'base64'
require 'active_support'
require 'active_support/core_ext/hash'

set :bind, '0.0.0.0'

UAA_TOKEN_SERVER = ENV['UAA_TOKEN_SERVER'] || "https://uaa.10.244.0.34.xip.io"
LOGIN_CLIENT_SECRET = ENV['LOGIN_CLIENT_SECRET'] || "login-secret"

# curl -H 'Accept: application/json' https://login.run.pivotal.io/login
get '/login' do
  log_request_and_params
  set_headers
  '{
    "timestamp": "2013-10-24T10:46:06-0700",
    "app": {
      "artifact": "cloudfoundry-login-server",
      "description": "Cloud Foundry Login Server",
      "name": "Cloud Foundry Login",
      "version": "1.2.7"
    },
    "links": {
      "register": "https://console.run.pivotal.io/register",
      "passwd": "https://console.run.pivotal.io/password_resets/new",
      "home": "https://console.run.pivotal.io",
      "login": "https://login.run.pivotal.io",
      "uaa": "https://uaa.run.pivotal.io"
    },
    "analytics": {
      "code": "UA-22181585-29",
      "domain": "pivotal.io"
    },
    "commit_id": "f5d7a7d",
    "prompts": {
      "username": ["text", "Email"],
      "password": ["password", "Password"]
    }
  }'
end

post '/oauth/token' do
  log_request_and_params
  # should check for valid user pw combination
  if params["username"] && params["password"]
    token_response_for_user(params["username"])
  elsif params["grant_type"]
   #FIXME Implement token refresh
  else
    halt 404
  end 
end

get '/*' do
  log_request_and_params
end

post '/*' do
  log_request_and_params
end


helpers do
  def log_request_and_params
    logger.debug request.inspect
    logger.debug params.inspect
  end

  def set_headers
    response.headers['content-type'] = 'application/json;charset=UTF-8'
  end
 
  def token_response_for_user(email)
    uaa_request_authorization_code(email)
  end

  def uaa_request_authorization_code(email)
    request_params = {
      "username" => "#{Yajl::Encoder.encode("username" => email)}", 
      "response_type" => "token",
      "source" => "login",
      "client_id" => "cf",
      "redirect_uri" => "#{UAA_TOKEN_SERVER}/oauth/token"
    }
    request_headers = {
      :authorization => "bearer #{login_access_token()}", 
      :accept => :json
    }
    uaa_response = post("#{UAA_TOKEN_SERVER}/oauth/authorize", request_params, request_headers)

    # FIXME find a better way to convert the location header to json
    location_header = uaa_response.headers[:location]
    location_params = CGI::parse(location_header.match(/#(.*)/).captures[0])
    location_params_hash = Hash[*location_params.flatten(2)]
    
    logger.debug location_params_hash

    location_params_hash.to_json
  end   

  def login_access_token
    # Get an access token for the login client
    login_response = post("#{UAA_TOKEN_SERVER}/oauth/token", \
                           {"response_type" => "token", "grant_type" => "client_credentials"}, \
                           {:accept => :json, :authorization => "Basic #{Base64.strict_encode64("login:#{LOGIN_CLIENT_SECRET}")}"})
    logger.debug "#{login_response.body.inspect}"
    access_token = Yajl::Parser.new.parse(login_response.body)["access_token"]
  end

  def post(url, content, headers = nil)
    begin
       response = RestClient.post(url, content, headers) \
        {|response, request, result, &block| response}
    rescue => e
      logger.error("Error connecting to #{url}, #{e.backtrace}")
      halt 500, "UAA unavailable."
    end
  end

end

configure :development do
  set :logging, Logger::DEBUG
end