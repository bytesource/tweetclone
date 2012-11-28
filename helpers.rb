helpers do
  
  
 # On completing authentication, RPX will call on Tweetclone 
 # at the URL (after_login) that was provided earlier on.
 # RPX passes a token parameter to us in this call, 
 # which we will use to retrieve the user's profile.
 def get_user_profile_with(token)
   response = RestClient.post 'https://rpxnow.com/api/v2/auth_info', 'token'    => token,
                                                                     'apiKey'   => '<api key>',
                                                                     'format'   => 'json',
                                                                     'extended' => 'true'
   json = JSON.parse(response)
   if json['stat'] == 'ok'
     return json['profile']
   else
     raise LoginFailedError, 'Cannot log in. Try another account!'
   end
 end 
 
 def load_user(id)
   @myself = User.first(:id => id)
   @user   = @myself
 end
 
 
 # Return the count of DIRECT messages
 # -- messages SENT TO USER     (recipient = user)
 # -- messages SENT BY the USER (recipient != nil)
 def message_count
   id = session[:userid]
   # sent_by_user = Status.filter(:owner_id => id).exclude(:recipient_id => nil).count # 1)
   # sent_to_user = Status.filter(:recipient_id => id).count
   # sent_by_user + sent_to_user
  
   # Using a single database query 
   # http://sequel.rubyforge.org/rdoc/files/doc/dataset_filtering_rdoc.html => "Using OR instead of AND"
   Status.filter(:owner_id => id).exclude(:recipient_id => nil). # 2)
              or(:recipient_id => id).
              count
 end
 
 # 1)
 # SELECT COUNT(*) AS "count" FROM "statuses" 
 #   WHERE (("owner_id" = 1) AND 
 #          ("recipient_id" IS NOT NULL)) 
 #   LIMIT 1

 # We simply run haml again on the given page, and 
 # include any parameters we pass to it, 
 # only telling the haml page not to use the default layout.
 
 # 2)
 # SELECT COUNT(*) AS "count" FROM "statuses" 
 #   WHERE ((("owner_id" = 1) AND ("recipient_id" IS NOT NULL)) 
 #     OR ("recipient_id" = 1)) 
 #   LIMIT 1
 
 def snippet(page, options={})
   haml page, options.merge!(:layout => false)
 end
 
  def time_ago_in_words(timestamp)
    minutes = (((Time.now - timestamp).abs)/60).round
    return nil if minutes < 0

    case minutes
    when 0          then 'less than a minute ago'
    when 0..4       then 'less than 5 minutes ago'
    when 5..14      then 'less than 15 minutes ago'
    when 15..29     then 'less than 30 minutes ago'
    when 30..59     then 'more than 30 minutes ago'
    when 60..119    then 'more than 1 hour ago'
    when 120..239   then 'more than 2 hours ago'
    when 240..479   then 'more than 4 hours ago'
    else            timestamp.strftime('%I:%M %p %d-%b-%Y')
    end
  end
  
  
  # API
  
  # This method responds to the client with a 
  # -- 401 Not Authorized status code as well as a 
  # -- WWW-Authenticate header and 
  # -- the authentication realm, 
  # unless the client is already authorized.
  def protected!
    if !authorized?
      response['WWW-Authenticate'] = %(Basic realm="TweetClone")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  
  # We check the authorization by 
  # -- getting a new instance of Rack's basic access authentication request 
  # and making sure that it's 
  # -- it's really HTTP basic access authentication and that 
  # --- credentials are provided. 
  # Then we run a check on the authorization credentials.
  def authorized?
     @auth ||= Rack::Auth::Basic::Request.new(request.env)
     @auth.provided? &&
     @auth.basic? &&
     @auth.credentials &&
     check(@auth.credentials)
  end
  
  def check(redentials) # array
    # email, password = *credentials
    email, password = credentials
    return false unless User.first(:email => email) 
    response = RequestClient.post 'https://www.google.com/accounts/ClientLogin',
                                  'accountType' => 'HOSTED_OR_GOOGLE', 
                                  'Email'       => email, 
                                  'Passwd'      => password, 
                                  :service      => 'xapi', 
                                  :source       => 'Goog-Auth-1.0'
    response.code == 200
  end
  
 
  
end

  

 
   
   
   
   
   
   
   

  












