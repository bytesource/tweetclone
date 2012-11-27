require 'sinatra'
require 'digest/md5'
require 'rack-flash'
require 'json'
require 'haml'
require_relative 'model'

set :sessions, true
set :show_exceptions, true
use Rack::Flash

#If the user is already logged in and has a session, 
# we will redirect him to his home page. 
# Otherwise, we will prepare the TOKEN for RPX, 
# which is a URL that RPX will call 
# after successfully authenticating the user.
get '/' do
  user = session[:userid]
  if user.nil?
    @token = "http://#{env['HTTP_HOST']}/after_login"  # will call our :after_login on completing authentication
    haml :login
  else # already logged in
    # redirect to user's homepage
    redirect "/#{User.first(:id => user).nickname}"
  end
end

# called by RPX after completion of the login
post '/after_login' do
  profile = get_user_profile_with params[:token]
  user = User.first(:identifier => profile['identifier'])
  if user
    session[:userid] = user.id
    redirect "/#{user.nickname}"
  else # user not in database => new user
    gravatar = "http://www.gravatar.com/avatar/" # returns default picture if user has not gravatar
    # check for email redundant as user has to login with his Gmail address.
    photo = profile['email'] ? "#{gravatar}#{Digest::MD5.hexdigest(profile['email'])}" : profile['photo']
    # If :nickname is empty, a random string is set, based on the hash of the identifier, 
    # converted into an alphanumeric string:
    nick = profile['nickname']
    nick = nick ? nick : profile['identifier'].to_hash.to_s(36) 
    
    user = User.new(:nickname  => nick, 
                    :email     => profile['email'], 
                    :photo_url => photo,
                    :provider  => profile['provider'])
    # TODO: Add validation to match all database constraints on the Users table.   
    # More save alternative (as all database constraints will be checked automatically)
    # User.raise_on_save_failure = false
    # user = user.create(...)
    # if !user
      # but then there are no error message to extract 
    if user.valid?
      user.save  
      session[:userid] = user.id
      redirect '/#{user.nickname}'
    else
      flash[:error] = user.errors.full_messages
      redirect '/change_profile'
    end
  end
end

get '/profile' do
  load_user(session[:userid])
  haml :profile
end

get '/change_profile' do 
  haml :change_profile 
end

# Data of web form from '/profile' (existent user) or '/change_profile' (not yet saved user)
post '/save_profile' do 
  user = User.first(:id => session[:userid])
  data = {:nickname       => params[:nickname], 
          :formatted_name => params[:formatted_name], 
          :location       => params[:location], 
          :description    => params[:description]}
  if user
    # http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/InstanceMethods.html#method-i-set
    user.set(data) 
    if user.valid?
      user.save_changes
      redirect "/#{user.nickname}"
    else
      flash[:error] = user.error.full_messages
      redirect '/change_profile'
    end
  # Error on save at '/after_login'. Got redirected to '/change_profile', resulting data redirected here.
  else
    user = User.new(data)
    if user.valid?
      user.save
      redirect "/#{user.nickname}"
    else
      flash[:error] = user.error.full_messages
      redirect '/change_profile'
    end
  end
end
      
get '/logout' do
  session[:userid] = nil
  redirect '/'
  # Without the user ID, the index route shows the login view.
end 


get '/:nickname' do
  load_user(session[:userid])
  # Example of @user != @myself
  # @myself logged in as 'Bytesource' opening the personal site of one of my followers.
  @user = @myself.nickname == params[:nickname] ? @myself : User.first(:nickname => params[:nickname])
  @message_count = message_count
  if @myself == @user # redundant: we already have this checked in #diplayed_statuses
    @statuses = @myself.displayed_statuses
    haml :home
  else 
    @statuses = @user.statuses
    haml :user
  end
end


# To post status updates, the user submits a post form on 'home.haml'. 
# The route then takes in the status text and creates the Status object. 
# Note that when the Status object is created and saved,
# the various processing logic in the before filter is called and executed. 
# After the status is saved to the database, the user is 
# redirected back to the home page, clearing the update text box.
post '/update' do
  user = User.first(session[:userid])
  message = Status.create(:text => params[:status])
  user.add_status(message)
  redirect "/#{user.nickname}"
end


get '/replies' do
  load_user(session[:userid])
  # Note: Sequel should return an empty array for an empty result by default.
  @statuses = @myself.mentioned_statuses || []  
  @message_count = message_count
  haml :replies
end

get '/tweets' do
  load_user(session[:userid])
  @status = @myself.statuses
  haml :user
end


get '/messages/:direction' do
  load_user(session[:userid])
  @friend = @myself.friends
  case params[:direction]
  when 'received' 
    @messages = Status.filter(:recipient_id => @myself.id).all
    @label    = "Direct messages sent only to you"
  when 'sent'
    @messages = Status.filter(:owner_id => @myself.id).exclude(:recipient_id => nil).all
    @label    = "Direct messages you've sent"
  end
  @message_count = message_count
  haml :messages
end

post '/message/send' do
  recipient = User.first(:nickname => params[:recipient])
  Status.create(:text         => params[:message],
                :owner_id     => User.first(:id => session[:userid]),
                :recipient_id => recipient)
  redirect '/messages/sent'
end


























  
