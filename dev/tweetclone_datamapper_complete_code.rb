class User
  include DataMapper::Resource
  property :id,             Serial
  property :email,          String, :length => 255
  property :nickname,       String, :length => 255
  property :formatted_name, String, :length => 255
  property :provider,       String, :length => 255
  property :identifier,     String, :length => 255
  property :photo_url,      String, :length => 255
  property :location,       String, :length => 255
  property :description,    String, :length => 255

  has n, :statuses
  has n, :direct_messages, :class_name => "Status"
  has n, :relationships
  has n, :followers, :through => :relationships, :class_name => "User", :child_key => [:user_id]
  has n, :follows, :through => :relationships, :class_name => "User", :remote_name => :user, :child_key => [:follower_id]
  has n, :mentions
  has n, :mentioned_statuses, :through => :mentions, :class_name => 'Status', :child_key => [:user_id], :remote_name => :status

  validates_is_unique :nickname, :message => "Someone else has taken up this nickname, try something else!"

  def self.find(identifier)
    u = first(:identifier => identifier)
    u = new(:identifier => identifier) if u.nil?
    return u
  end

  def displayed_statuses
    statuses = []
    statuses += self.statuses.all(:recipient_id => nil, :limit => 10,
                                  :order => [:created_at.desc]) # don't show direct messsages
    self.follows.each do |follows| statuses += follows.statuses.
      all(:recipient_id => nil, :limit => 10, :order => [:created_at.desc])
    end if @myself == @user
    statuses.sort! { |x,y| y.created_at <=> x.created_at }
    statuses[0..10]
  end
end


class Relationship
  include DataMapper::Resource
  property :user_id,     Integer, :key => true
  property :follower_id, Integer, :key => true

  belongs_to :user,     :child_key => [:user_id]
  belongs_to :follower, :class_name => "User", :child_key => [:follower_id]
end

class Mention
  include DataMapper::Resource
  property :id, Serial

  belongs_to :user
  belongs_to :status
end


class Status
  include DataMapper::Resource
  property :id, Serial
  property :text, String, :length => 140
  property :created_at, DateTime
  belongs_to :recipient, :class_name => "User", :child_key => [:recipient_id]
  belongs_to :user

  has n, :mentions
  has n, :mentioned_users, :through => :mentions, :class_name => 'User', :child_key => [:user_id]

  before :save do
    @mentions = []
    case
    when text,starts_with('D ')
      process_direct_message
    when text.starts_with('follow ')
      process_follow
    else
      process
    end
  end

  after :save do
    unless @mentions.nil?
      @mentions.each {|m|
        m.status = self
        m.save
      }
    end
  end

  # general scrubbing
  def process
    # process url
    urls = self.text.scan(URL_REGEXP)
    urls.each { |url|
      tiny_url = open("http://tinyurl.com/api-create.php?url=#{url[0]}") {|s| s.read}
      self.text.sub!(url[0], "<a href='#{tiny_url}'>#{tiny_url}</a>")
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
  # process direct messages
  def process_direct_message
    self.recipient = User.first(:nickname => self.text.split[1])
    self.text = self.text.split[2..-1].join(' ') # remove the first 2
    words
    process
  end
  # process follow commands
  def process_follow
    Relationship.create(:user => User.first(:nickname => self.text.
                                            split[1]), :follower => self.user)
    throw :halt # don't save
  end
  def to_json(*a)
    {'id' => id, 'text' => text, 'created_at' => created_at, 'user' =>
     user.nickname}.to_json(*a)
  end
end
URL_REGEXP = Regexp.new('\b ((https?|telnet|gopher|file|wais|ftp) : [\w/#~:.?+=&%@!\-] +?) (?=[.:?\-] * (?: [^\w/#~:.?+=&%@!\-]| $ ))', Regexp::EXTENDED)
AT_REGEXP = Regexp.new('@[\w.@_-]+', Regexp::EXTENDED)













