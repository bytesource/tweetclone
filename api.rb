get '/api/statuses/user_timeline' do
  protected!
  # email = *@auth.credentials
  email = @auth.credentials  # Is email the first item in the array?
  user = User.first(:email => email)  # got email during authentication
  if user  # redundant: we already checked for user in #check (see helpers.rb)
    # to_json recursively calls to_json on every item in the array 1)
    user.displayed_statuses.to_json   
  end
end


# 1)
class Test
  def to_json(*a)  
  {:class => "test", :value => "personal class"}.to_json(*a)    
  end  
end  
# => nil
[Test.new].to_json
# => "[{\"class\":\"test\",\"value\":\"personal class\"}]"


# Return all status objects
get 'api/statuses/public_timeline' do
  protected!
  Status.all.to_json
end

# We require the client to use HTTP POST
# POST needs to pass a 'text' parameter
post '/api/statuses/update' do
  protected!
  email = @auth.credentials
  User = User.first(:email => email)  
  if user # redundant: we already checked for user in #check (see helpers.rb)
    status = Status.new(:text => params[:text], :owner_id => user.id)
    # If all goes well we stop here, 
    # otherwise we throw a halt and stop processing.
    raise_on_save_failure = false
    throw(:halt, [401, "Not authorized\n"]) if !status.save # returns nil on failure
    raise_on_save_failure = true
  end
end





















