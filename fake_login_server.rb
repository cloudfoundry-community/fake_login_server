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
    headers authorize_by_email(params["username"]).headers.stringify_keys!
    logger.debug "BODY: #{authorize_by_email(params["username"]).body.to_json}"
#     '{
#       "access_token":"eyJhbGciOiJSUzI1NiJ9.eyJqdGkiOiI5NjViMGRjNy04ZjRlLTQwMmItODVlNi1hZTg4ZTk2MGExMTgiLCJzdWIiOiJkMmYyZTU2Mi01YjJhLTQ2M2EtODQyMy1kNjk5MDU2NzRmYTkiLCJzY29wZSI6WyJjbG91ZF9jb250cm9sbGVyLnJlYWQiLCJjbG91ZF9jb250cm9sbGVyLndyaXRlIiwib3BlbmlkIiwicGFzc3dvcmQud3JpdGUiXSwiY2xpZW50X2lkIjoiY2YiLCJjaWQiOiJjZiIsImdyYW50X3R5cGUiOiJwYXNzd29yZCIsInVzZXJfaWQiOiJkMmYyZTU2Mi01YjJhLTQ2M2EtODQyMy1kNjk5MDU2NzRmYTkiLCJ1c2VyX25hbWUiOiJydWJlbi5rb3N0ZXJAaW5ub3ZhdGlvbmZhY3RvcnkuZXUiLCJlbWFpbCI6InJ1YmVuLmtvc3RlckBpbm5vdmF0aW9uZmFjdG9yeS5ldSIsImlhdCI6MTM4MzkzODcyOCwiZXhwIjoxMzgzOTM5MzI4LCJpc3MiOiJodHRwczovL3VhYS5ydW4ucGl2b3RhbC5pby9vYXV0aC90b2tlbiIsImF1ZCI6WyJvcGVuaWQiLCJjbG91ZF9jb250cm9sbGVyIiwicGFzc3dvcmQiXX0.SjN_UFKb6DXA6AlOFLVc10vCGDdwCTkQJ09u0LFz1aTCaXdLqMKrPPVTz_Bq3Tx9V8TJTT7YJMouYUOSd40cFHBZhEOG8UScBffytTBLBtlEu4PjzjaQmH7DDZIoS7HPkZl5xcDfyPrCFcq2jJmY62V_idSATkMvx98oApoYbkJIZOLewrPVYCHGruKEPClhCPh-7ISTRIh3JLTEPnje-0Ozj4bzWko-4b2Di2atrywwHSkRPj1a-B2MUHO_PdvupjR7pf56kqkW9MCYbtIw-TBtgdpjqkNKUObXftdTMTNGCKixmWqf6uRu_oe3708ZZml3vMZDZEzrVYNB3abBjw",
#       "token_type":"bearer",
#       "refresh_token":"eyJhbGciOiJSUzI1NiJ9.eyJqdGkiOiJjNjljMWRlMy1mYjhjLTQ3NWMtODczZC1lMmEzYWYyNmMxYjgiLCJzdWIiOiJkMmYyZTU2Mi01YjJhLTQ2M2EtODQyMy1kNjk5MDU2NzRmYTkiLCJzY29wZSI6WyJjbG91ZF9jb250cm9sbGVyLnJlYWQiLCJjbG91ZF9jb250cm9sbGVyLndyaXRlIiwib3BlbmlkIiwicGFzc3dvcmQud3JpdGUiXSwiaWF0IjoxMzgzOTM4NzI4LCJleHAiOjEzODY1MzA3MjcsImNpZCI6ImNmIiwiaXNzIjoiaHR0cHM6Ly91YWEucnVuLnBpdm90YWwuaW8vb2F1dGgvdG9rZW4iLCJncmFudF90eXBlIjoicGFzc3dvcmQiLCJ1c2VyX25hbWUiOiJydWJlbi5rb3N0ZXJAaW5ub3ZhdGlvbmZhY3RvcnkuZXUiLCJhdWQiOlsiY2xvdWRfY29udHJvbGxlci5yZWFkIiwiY2xvdWRfY29udHJvbGxlci53cml0ZSIsIm9wZW5pZCIsInBhc3N3b3JkLndyaXRlIl19.B_A33aS_4j58uesKS5CvnQhGRrqp2HCjRPrTB5ZEWlhyn8HfiGETnH0hGnRBXXh04LBw6AoFPEM0VUSJhK5oDQKXJbD7sCaZmNSYHY65FJMagFxcgqC9-_Xa0PfNiVa4zCH61MOVOtW5oh8kvd-031kHd6JdRXsESpCcHpTmveE6L5x-eQNs64cQXrEfxTr1GrLgWt8hJZYXtFxr9iTvf70vQKsiYWeWn72MOZVFdYOt7vG7m7YcFoGDBCWweib-ouZ0wLnTstJ0o1voN8XmEqN9dwzFmcIcNqQVrVeahC3RHPeVbT7jFbXk0_1K_uA9Oo7YpsvyrI9DJbuE-Qcmsg",
#       "expires_in":599,
#       "scope":"cloud_controller.read cloud_controller.write openid password.write",
#       "jti":"965b0dc7-8f4e-402b-85e6-ae88e960a118"
#     }'
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
 
  def authorize_by_email(email)
    logger.debug "authenticated email address #{email}"
    # Post the credentials and get a session with the uaa. Save the uaa cookie
    uaa_response = post_to_authorize({"username" => "#{Yajl::Encoder.encode("username" => email)}", 
      "response_type" => "code",
      "source" => "login",
      "client_id" => "login"}, \
      {:authorization => "bearer #{login_access_token()}"})
    logger.debug "#{uaa_response.headers.inspect}"
    uaa_response 
  end

  def post_to_authorize(request_params, headers)
    headers = headers.merge(:accept => :json)
    logger.debug("Headers to post to authorize #{headers}")
    post("#{UAA_TOKEN_SERVER}/oauth/authorize", request_params, headers)
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