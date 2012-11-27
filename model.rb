require 'open-uri'
require_relative "db/tables"

URL_REGEXP = Regexp.new('\b ((https?|telnet|gopher|file|wais|ftp) : [\w/#~:.?+=&%@!\-] +?) (?=[.:?\-] * (?: [^\w/#~:.?+=&%@!\-]| $ ))', Regexp::EXTENDED)
AT_REGEXP  = Regexp.new('@[\w.@_-]+', Regexp::EXTENDED) # starts with @, followed by any number of allowed.

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


class Status < Sequel::Model
  
  # str = "a.c"    => "a.c"
  # re  = /#{str}/ => /a.c/
  def starts_with(regex)
    /\A#{regex}/
  end
    
  def before_save
    @mentions = []
    case self.text                    # self => object instance
    when starts_with(/D\s/)           # direct message
      process_direct_message
    when starts_with(/(F|f)ollows\s/)
      process_follow
      # http://sequel.rubyforge.org/rdoc/files/doc/model_hooks_rdoc.html => Halting Hook Processing
      return false # Halt saving of self, as a 'follows' message is not a real message.
    else
      process
    end
    
    super  # Don't forget to call super when overriding Sequel::Model's methods
  end
  
  # def after_save 
  #   unless @mentions.nil?  # @mentions = [Mention instance, Mention instance, ...]
  #     @mentions.each do |m|
  #       m.status = self
  #       m.save
  #     end
  #   end
  # end
  
  def after_save 
    unless @mentions.nil? # @mentions = ['nick1', 'nick2', ...]
      @mentions.each do |nickname|
        Mention.create(:user_id => nickname, :status_id => self.id) # self already saved to database => We have self.id
      end
    end
    
    super
  end
  
  
  def process
    # process URLs
    process_embedded_urls(self.text)
    # process @
    process_embedded_mentions(self.text)
  end
  
  def process_embedded_urls(message)
    urls = self.text.scan(URL_REGEXP)
    urls.each do |url|
      # OpenURI::OpenRead#open 
      # If block given, yields the IO object and returns the value of the block.
      # Example: http://tinyurl.com/api-create.php?url=http://www.sovonex.com
      #          s = http://tinyurl.com/a3owap5
      tiny_url = open("http://tinyurl.com/api-create.php?url=#{url}") { |s| s.read } # changed url[0] to url
      self.text.sub!(url, "<a href='#{tiny_url}'>#{tiny_url}</a>")
    end
  end
  
  def process_embedded_mentions(message)
    at_signs = self.text.scan(AT_REGEXP)
    at_signs.each do |at|
      nickname = at[1..-1]  # remove @ from nickname
      user     = User.first(:nickname => nickname) 
      if user
        self.text.sub!(at, "<a href='/#{user.nickname}'>#{at}</a>}") # Link to nickname's statuses
        # @mentions << Mention.new(:user_id => nickname, :status_id => self.id) # will be saved in #after_save
        # Problem: self not saved to database yet (we are inside #before_save) so there is no self.id
        # Solution: We store the nicknames of all mentioned users in an array and create and save Mention instances
        #           AFTER self (this status) has been save to the database.
        @mentions << nickname
      end
    end
  end
  
  # Process direct messages
  def process_direct_message
    addressee = User.first(:nickname => self.text.split[1])  # text.split => ['D', 'nickname', 'many', 'more', 'words']
    self.recipient = addressee.id
    self.text = self.text.split[2..-1].join(' ')             # remove the first 2 words
    process
  end
  
  # Process follow commands
  def process_follow
    user     = User.first(:nickname => self.text.split[1]) 
    Relationship.create(:user => user.id, :follower => self.owner)
    # We stop processing at this point because we don't want to save the tweet (
    # it's not really a tweet but a command to Tweetclone), 
    # so we throw a halt exception, which DataMapper will interpret, stopping the save from proceeding.
    # throw :halt
    # NOTE: Using Sequel we return false in #before_save to stop saving of the status to the database.
    # http://sequel.rubyforge.org/rdoc/files/doc/model_hooks_rdoc.html => Halting Hook Processing
  end
  
  def to_json(*a)
    {'id' => id, 'text' => text, 'created_at' => created_at, 'owner' => owner}.to_json(*a)
  end
  
end

  
  

  
  

    
