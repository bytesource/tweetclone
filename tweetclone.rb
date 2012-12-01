# Deployed at:
# http://chatcloud.herokuapp.com
# (Application error because of problems with the database)


require 'sinatra'
require 'rest-client'  # NOT 'restclient'
require 'digest/md5'
# require 'rack-flash'
require 'json'
require 'haml'

# http://sinatra-book.gittr.com/#hello_world_application
require 'bundler/setup'

require_relative 'model'
require_relative 'helpers'  # not found automatically

# Use Shotgun:
# gem install shotgun
# shotgun -p 4567 tweetclone.rb
# source: http://ruby.about.com/od/sinatra/a/sinatra5.htm

# =======================

# Rack::Flash not working anymore:
# https://github.com/nakajima/rack-flash/issues/8
# use Rack::Flash

# Alternative: use sinatra-flash
# https://github.com/SFEley/sinatra-flash
# gem install sinatra-flash
require 'sinatra/flash'

# http://www.sinatrarb.com/configuration.html
set :sessions, true
set :show_exceptions, true

#If the user is already logged in and has a session, 
# we will redirect him to his home page. 
# Otherwise, we will prepare the TOKEN for RPX, 
# which is a URL that RPX will call 
# after successfully authenticating the user.
get '/' do
  user = session[:userid]
  puts "session[:userid] = #{session[:userid]}---------------------------"
  if user.nil? || !User.first(:id => user) # session id still set, but database is empty (happens during development)
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
    puts "my profile ___________________________________"
    p profile
    gravatar = "http://www.gravatar.com/avatar/" # returns default picture if user has not gravatar
    # check for email redundant as user has to login with his Gmail address.
    photo = profile['email'] ? "#{gravatar}#{Digest::MD5.hexdigest(profile['email'])}" : profile['photo']
    # If :nickname is empty, a random string is set, based on the hash of the identifier, 
    # converted into an alphanumeric string:
    nick = profile['nickname']
    nick = nick ? nick : profile['identifier'].hash.to_s(36) 
    # Example profile: http://developers.janrain.com/documentation/api-methods/engage/auth_info/
    user = User.new(:nickname       => nick, 
                    :formatted_name => profile['name']['formatted'],
                    :email          => profile['email'], 
                    :photo_url      => photo,
                    :provider       => profile['providerName'],
                    :identifier     => profile['identifier'])
    # TODO: Add validation to match all database constraints on the Users table.   
    # More save alternative (as all database constraints will be checked automatically)
    # User.raise_on_save_failure = false
    # user = user.create(...)
    # if !user
      # but then there are no error message to extract 
    if user.valid?
      user.save 
      # Load new instance from database to get hold of the primary key id
      user = User.first(:nickname => nick) 
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
      flash.now[:error] = user.errors.full_messages
      # http://stackoverflow.com/questions/2704772/passing-data-between-blocks-using-sinatra
      haml :change_profile, :locals => {:user => user}
      # flash[:error] = user.error.full_messages
      # redirect '/change_profile'
    end
  # Error on save at '/after_login'. Got redirected to '/change_profile', resulting data redirected here.
  else
    user = User.new(data)
    if user.valid?
      user.save
      redirect "/#{user.nickname}"
    else
      flash.now[:error] = user.error.full_messages
      haml :change_profile, :locals => {:user => user}
      # flash[:error] = user.error.full_messages
      # redirect '/change_profile'
    end
  end
end
      
get '/logout' do
  session[:userid] = nil
  redirect '/'
  # Without the user ID, the index route shows the login view.
end 


# To post status updates, the user submits a post form on 'home.haml'. 
# The route then takes in the status text and creates the Status object. 
# Note that when the Status object is created and saved,
# the various processing logic in the before filter is called and executed. 
# After the status is saved to the database, the user is 
# redirected back to the home page, clearing the update text box.
post '/update' do
  user = User.first(:id => session[:userid])
  message = Status.create(:text => params[:status], :owner_id => user.id) # made :owner_id :null => false to be safe
  # user.add_status(message)   This did not work for some reason
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

# followers of logged in user
get '/followers' do
  load_user(session[:userid])
  @users = @myself.followers
  @message_count = message_count
  haml :followers
end


# users that logged in user is following
get '/follows' do
  load_user(session[:userid])
  @users = @myself.follows
  @message_count = message_count
  haml :follows
end

# NOTE from the book:
# Notice that we did not do anything to secure the usage of the following features. 
# To re-iterate what was mentioned earlier, 
# the code in this chapter and in the whole book has only feature considerations 
# and not security or exception handling.

# Catch-all :nickname root to be placed after all more specific routes like 'update', 'replies', etc.
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


get '/messages/:direction' do
  load_user(session[:userid])
  @friends = @myself.friends
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




# To follow a user with the nickname Tom ,we go to the URL
# address http://tweetclone.saush.com/follow/tom. 
get '/follow/:nickname' do
  user_id     = User.first(:nickname => params[:nickname]).id
  follower_id = User.first(:id => session[:userid]) # logged-in user
  unless Relationship.first(:user_id => user_id, :follower_id => follower_id)
    Relationship.create(:user_id => user_id, :follower_id => follower_id)
  end
  redirect "/#{params[:nickname]}"
end

# To delete a follows relationship, we pass in 
# -- the follower ID and 
# -- the ID of the user being followed 
# Question:
# Why not use :nickname instead of :id as above?
# Why not get :follower_id from session id as above?
# => delete 'follow/:nickname' do
delete 'follow/:follower/:followed' do
  user_id      = params[:followed].id
  follower_id  = params[:follower].id
  relationship = Relationship.first(:user_id => user_id, :follower_id => follower_id)
  relationship.destroy
end































