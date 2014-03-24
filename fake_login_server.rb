require 'sinatra'
require 'restclient'
require 'yajl'
require 'yajl/json_gem'
require 'logger'
require 'base64'

set :bind, '0.0.0.0'

UAA_TOKEN_SERVER = ENV['UAA_TOKEN_SERVER'] || "https://uaa.10.244.0.34.xip.io"
LOGIN_CLIENT_SECRET = ENV['LOGIN_CLIENT_SECRET'] || "login-secret"

# curl -H 'Accept: application/json' https://login.run.pivotal.io/login
get '/login' do
  log_request_and_params
  set_headers
  "{
    \"timestamp\": \"2013-10-24T10:46:06-0700\",
    \"app\": {
      \"artifact\": \"cloudfoundry-login-server\",
      \"description\": \"Cloud Foundry Login Server\",
      \"name\": \"Cloud Foundry Login\",
      \"version\": \"1.2.7\"
    },
    \"links\": {
      \"register\": \"https://console.run.pivotal.io/register\",
      \"passwd\": \"https://console.run.pivotal.io/password_resets/new\",
      \"home\": \"https://console.run.pivotal.io\",
      \"login\": \"https://login.run.pivotal.io\",
      \"uaa\": \"#{UAA_TOKEN_SERVER}\"
    },
    \"analytics\": {
      \"code\": \"UA-22181585-29\",
      \"domain\": \"pivotal.io\"
    },
    \"commit_id\": \"f5d7a7d\",
    \"prompts\": {
      \"username\": [\"text\", \"Email\"],
      \"password\": [\"password\", \"Password\"]
    }
  }"
end

post '/oauth/token' do
  log_request_and_params
  set_headers
  # should check for valid user pw combination
  if params["username"] && params["password"]
    token_response_for_user(params["username"])
  elsif params["grant_type"] == "refresh_token"
    token_response_for_user(user_for_refresh_token(params["refresh_token"]))
  else
    halt 404
  end
end

get '/Users' do
  redirect UAA_TOKEN_SERVER + request.fullpath
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
    request_params = {
      "username" => "#{Yajl::Encoder.encode("username" => email)}",
      "email" => "#{Yajl::Encoder.encode("username" => email)}",
      "given_name" => "Foo",
      "family_name" => "Bar",
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

    # example location header:
    # https://uaa.10.244.0.34.xip.io/oauth/token;jsessionid=example_session_id# \
    # access_token=example_access_token&token_type=bearer&expires_in=599& \
    # scope=scim.read%20cloud_controller.admin%20password.write%20scim.write%20cloud_controller.write%20openid%20cloud_controller.read&jti=example_jti
    location_header = uaa_response.headers[:location]

    # example location params
    # {
    #   "access_token" => ["exmaple_access_token"],
    #   "token_type"=>["bearer"],
    #   "expires_in"=>["599"],
    #   "scope"=>["scim.read cloud_controller.admin password.write scim.write cloud_controller.write openid cloud_controller.read"],
    #   "jti"=>["example_jti"]
    # }
    location_params = CGI::parse(location_header.match(/#(.*)/).captures[0])

    # example location params hash
    # {
    #   "access_token" => "exmaple_access_token",
    #   "token_type"=>"bearer",
    #   "expires_in"=>"599",
    #   "scope"=>"scim.read cloud_controller.admin password.write scim.write cloud_controller.write openid cloud_controller.read",
    #   "jti"=>"example_jti"
    # }
    location_params_hash = Hash[*location_params.flatten(2)]

    # example location params hash in json
    # {
    #   "access_token" : "exmaple_access_token",
    #   "token_type" : "bearer",
    #   "expires_in" : "599",
    #   "scope" : "scim.read cloud_controller.admin password.write scim.write cloud_controller.write openid cloud_controller.read",
    #   "jti" : "example_jti"
    # }
    location_params_hash["refresh_token"] = refresh_token_for_user(email)
    logger.debug location_params_hash.inspect
    location_params_hash.to_json
  end

  def refresh_token_for_user(email)
    #Should implement secure refresh token generation
    Base64.strict_encode64(email)
  end

  def user_for_refresh_token(token)
    Base64.strict_decode64(token)
  end

  def login_access_token
    request_params = {
      "response_type" => "token",
      "grant_type" => "client_credentials"
    }
    request_headers = {
      :accept => :json,
      :authorization => "Basic #{Base64.strict_encode64("login:#{LOGIN_CLIENT_SECRET}")}"
    }
    # Get an access token for the login client
    login_response = post("#{UAA_TOKEN_SERVER}/oauth/token", request_params, request_headers)
    # logger.debug "#{login_response.body.inspect}"
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
