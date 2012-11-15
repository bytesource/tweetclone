require_relative "db/tables"

class User < Sequel::Model
  plugin :validation_helpers
  
  def validate
    super
    validates_unique :nickname
  end
  
  # Return a user, given the OpenID identifier. 
  def self.find(identifier)
    u = first(:identifier => identifier)
    u = new(:identifier => identifier)  if u.nil?
  end
  # From the book:
  # We will check if user is a new record later on, 
  # using the #new_record? method on the object. 
  # If it's an object that is tied with an actual database record, it will be considered an existing record 
  # and we will never be able to update any further attributes.
  # TODO: Sequel does not have a #new_record? function
  # Possible solution: Instead of defining #find above, just use #first, and check for 'nil'.

  

  # Return those messages of user that are not direct messages.
  def query(user)
    # :recipient => nil ... (only direct messages have a recipient)
    # http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html => dataset_methods
    # user.statuses_dataset.filter(:recipient => nil).limit(10).order(:created_at)
    user.statuses { |ds| ds.filter(:recipient => nil).limit(10).order(:created_at)}
    # "SELECT * FROM \"statuses\" 
    #    WHERE ((\"statuses\".\"user_id\" = 2) AND 
    #          (\"recipient\" IS NULL))
    #    ORDER BY \"created_at\" 
    #    LIMIT 10">
  end
  
  # Retrieve all statuses that are relevant to this user:
  # -- Messages he posted himself.
  # -- Messages of people he follows.
  def displayed_statuses
    statuses = []
    statuses += self.query.all
   
    if @myself == @user  # TODO: I don't think the 'self' below is necessary => check
      self.follows.each { |follows| statuses += query(follows).all }  # ORDER BY clause not really necessary as we sort below anyway.
    end
    
    statuses.sort! { |x, y| y.created_at <=> x.created_at }   # statuses.sort_by! { |status| -status.created_at }
    statuses[0..10]                                           # statuses.take(10)
  end
end

user1 = User.create
user2 = User.create
p user1.query(user2)
# "SELECT * FROM \"statuses\" WHERE (\"statuses\".\"user_id\" = 2)">
p user1.relationships
# SELECT "users".* FROM "users" 
#    INNER JOIN "relationships" ON (("relationships"."follower_id" = "users"."id") AND 
#                                   ("relationships"."user_id" = 5))
# p user1.followers
# SELECT "users".* FROM "users" 
#    INNER JOIN "relationships" ON (("relationships"."follower_id" = "users"."id") AND 
#                                   ("relationships"."user_id" = 3))
# p user1.follows
# SELECT "users".* FROM "users" 
#    INNER JOIN "relationships" ON (("relationships"."user_id" = "users"."id") AND 
#                                   ("relationships"."follower_id" = 3))

class Status < Sequel::Model
  
  # str = "a.c"    => "a.c"
  # re  = /#{str}/ => /a.c/
  def starts_with(regex)
    /\A#{regex}/
  end
    
  def before_save
    @mentions = []
    case self.text                    # self => object instance
    when starts_with("D ")            # direct message
      process_direct_message
    when starts_with("follows ")
      process_follow
    else
      process
  end
  
  def after_save
    unless @mentions.nil?
      @mentions.each do |m|
        m.status = self
        m.save
      end
    end
  end
 
  def process
    # process URL
    urls = self.text.scan(URL_REGEXP)
    urls.each do |url|
      tiny_url = open("http://tinyurl.com/api-create.php?url=")
    end
  end
    

  

 def process
  # process url
  urls = self.text.scan(URL_REGEXP)
  urls.each { |url|
    tiny_url = open("http://tinyurl.com/api-create.php?url=#{url[0]}") {|s| s.read}
    self.text.sub!(url[0], "<a href='#{tiny_url}'>#{tiny_url}</a>") # url[0] should be url
  }
  # process @
  ats = self.text.scan(AT_REGEXP)
  ats.each { |at|
    user = User.first(:nickname => at[1,at.length])
    if user
      self.text.sub!(at, "<a href='/#{user.nickname}'>#{at}</a>")
      @mentions << Mention.new(:user => user, :status => self)
    end
  }
end




end