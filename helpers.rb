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
  
end