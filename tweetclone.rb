require 'sinatra'
require 'digest/md5'
require 'rack-flash'
require 'json'
require 'models'
require 'haml'

set :sessions, true
set :show_exceptions, false
use Rack::Flash

get '/' do
  user = session[:userid]
  if user.nil?
    #  Token for RPX, which is a URL that 
    # RPX can call after it successfully authenticates the user.
    @token = "http://#{env['HTTP_HOST']}/after_login"
    haml :login
  else # already logged in
    # redirect to user's homepage
    redirect "/#{User.first(:nickname => user).nickname}"
  end
end
