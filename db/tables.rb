# Create database
# CREATE DATABASE tweetclone WITH ENCODING 'UTF-8'

require 'sequel'
require 'logger'

# CONNECTION ================================

DB = Sequel.connect(ENV['DATABASE_URL'] ||'postgres://postgres:blablabla@localhost/tweetclone')

# Logging SQL Queries
DB.loggers << Logger.new($stdout)

# http://sequel.rubyforge.org/rdoc/classes/Sequel/Inflections.html
Sequel.inflections do |inflect|
  inflect.irregular 'status', 'statuses'
end

# TABLES =====================================

# NOTE: parent table :users has to be the first as the following tables reference its
#       primary key.
#       Likewise, drop table :users using 'cascade': DROP TABLE USERS CASCADE;
#                                                    drop table users, statuses, relationships, mentions cascade;
DB.create_table? :users do
  primary_key :id
  String      :nickname,       :size => 255, :unique => true
  String      :email,          :size => 255
  String      :formatted_name, :size => 255# , :null => false
  String      :provider,       :size => 255# , :null => false
  String      :identifier,     :size => 255# , :null => false    # Google OpenID identifier used by RPX (1)
  String      :phote_url,      :size => 255# , :null => false
  String      :location,       :size => 255# , :null => false
  String      :description,    :size => 255# , :null => false
end

# (1)
# :identifier format example: 
# https://www.google.com/accounts/o8/id?id=AItOawnFFjWL15Ie5xEw4EB4RBxnd_ervO



DB.create_table? :statuses do
  primary_key :id
  # http://sequel.rubyforge.org/rdoc/classes/Sequel/Schema/Generator.html#method-i-column
  # :key
  # For foreign key columns, the column in the associated table that this column references. 
  # Unnecessary if this column references the primary key of the associated table, 
  # EXCEPT if you are using MySQL.
  
  # http://sequel.rubyforge.org/rdoc/classes/Sequel/Schema/Generator.html#method-i-foreign_key
  # foreign_key(:artist_id, :artists, :type=>String) # artist_id varchar(255) REFERENCES artists(id)
  # foreign_key :recipient_id,   :users, :key => :nickname, :type => String, :on_update => :cascade, :on_delete => :set_null
  foreign_key :recipient_id,   :users, :key => :id, :on_update => :cascade, :on_delete => :set_null
  # :on_update, :on_delete: see http://sequel.rubyforge.org/rdoc/files/doc/schema_modification_rdoc.html
  # foreign_key :owner_id,       :users, :key => :nickname, :type => String, :on_update => :cascade, :on_delete => :cascade   # who is the sender
  foreign_key :owner_id,       :users, :key => :id, :on_update => :cascade, :on_delete => :cascade   # who is the sender
  String      :text,        :size => 140, :null => false
  DateTime    :created_at,  :null => false
end

DB.create_table? :relationships do # join table users <=> users
  # foreign_key :user_id,     :users, :key => :nickname, :type => String, :on_update => :cascade, :on_delete => :cascade
  foreign_key :user_id,     :users, :key => :id, :on_update => :cascade, :on_delete => :cascade
  # foreign_key :follower_id, :users, :key => :nickname, :type => String, :on_update => :cascade, :on_delete => :cascade
  foreign_key :follower_id, :users, :key => :id, :on_update => :cascade, :on_delete => :cascade
  primary_key [:user_id, :follower_id]   # 1)
end

DB.create_table? :mentions do     # join table users <=> statuses
  # foreign_key :user_id,      :users,    :key => :nickname, :type => String, :on_update => :cascade, :on_delete => :cascade
  foreign_key :user_id,      :users,    :key => :id, :on_update => :cascade, :on_delete => :cascade
  foreign_key :status_id,    :statuses, :key => :id, :on_update => :cascade, :on_delete => :cascade
  primary_key [:user_id, :status_id]
end


# ASSOCIATIONS ===============================

# 1) The Relationship class defines the many-to-many relationship between users,
#    that is it defines who follows who. 
# 2) The Mention class defines the many-to-many relationship between users and statuses (aka tweets). 
#    -- Each status can mention one or more users and 
#    -- each user can be mentioned in one or more statuses. 
# 3) A user can have one or more statuses, 
#    while only one user can be the recipient of a status. 
# 4) A user can also have one or more direct messages (because we're modeling direct messages with statuses.)


class User < Sequel::Model
  one_to_many  :statuses, :key => :owner_id      
  # The :key option must be used if the default column symbol that Sequel would use is not the correct column.
  # one_to_many: :key points to FOREIGN KEY OF ASSOCIATION - see 3)
  one_to_many  :direct_messages, :class => :Status, :key => :recipient_id 
  
               # :left_primary_key => 'default: PK of current table', :right_primary_key => 'default: PK of associated table'
  many_to_many :followers,       
               :class => self,    :join_table => :relationships, :left_key => :user_id, :right_key => :follower_id
  many_to_many :follows,         
               :class => self,    :join_table => :relationships, :right_key => :user_id, :left_key => :follower_id
  many_to_many :mentions,        
               :class => :Status, :join_table => :mentions, :left_key => :user_id, :right_key => :status_id
  many_to_many :mentioned_statuses,   
               :class => :Status, :join_table => :mentions, :left_key => :status_id, :right_key => :user_id
   
  # A follows B and B follows A
  # https://groups.google.com/forum/?fromgroups=#!topic/sequel-talk/x9bcFIaGZX4         
  def friends
    followers & follows
  end
end

# Friends association using ::many_to_many
# User.many_to_many :friends, :class=>User, 
#                   :dataset=>proc{User.join(:relationships___ru, :user_id => :nickname).
#                                       join(:relationships___rf, :follower_id=>:users__nickname).
#                                       where(:ru__follower_id=>nickname, :rf__user_id=>nickname)}
                                      
# Writing an eager loader for the association is left as an exercise to the reader. :)

# http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/ClassMethods.html#method-i-unrestrict_primary_key
User.unrestrict_primary_key
# Allow the setting of the primary key(s) when using the mass assignment methods. 
# Using this method can open up security issues, be very careful before using it.

# Artist.set(:id=>1) # Error
# Artist.unrestrict_primary_key
# Artist.set(:id=>1) # No Error

# ______________________________________________________________
# NOTE: Don't give association and key column the same name! 
# Otherwise you will get the following error:
# => stack level too deep (SystemStackError)
# ______________________________________________________________


class Status < Sequel::Model  
  many_to_one  :recipient,       :class => :User, :key => :recipient_id # *to_one: :key points to FOREIGN KEY OF SELF - see 3)
  many_to_one  :owner,           :class => :User, :key => :owner_id
  many_to_many :mentions,        :class => :User, :join_table => :mentions, :left_key => :status_id, :right_key => :user_id
  many_to_many :mentioned_users, :class => :User, :join_table => :mentions, :left_key => :user_id, :right_key => :status_id
  
  # http://sequel.rubyforge.org/rdoc/files/doc/model_hooks_rdoc.html
  def before_create # right before insert
    self.created_at ||= Time.now
    super # ($)
  end
  
  
  
end

# ($)
# The one important thing to note here is the call to super inside the hook. 
# Whenever you override one of Sequel::Model's methods, you should be calling super to get the default behavior. 


# Datamapper Associations:

# User -----------------------------
# property :id,             Serial
# property :email,          String, :length => 255
# property :nickname,       String, :length => 255
# property :formatted_name, String, :length => 255
# property :provider,       String, :length => 255
# property :identifier,     String, :length => 255
# property :photo_url,      String, :length => 255
# property :location,       String, :length => 255
# property :description,    String, :length => 255

# has n, :statuses
# has n, :direct_messages,    :class_name => "Status"
# has n, :relationships
# has n, :followers,          :through => :relationships, :class_name => "User", :child_key => [:user_id]
# has n, :follows,            :through => :relationships, :class_name => "User", :remote_name => :user, :child_key => [:follower_id]
# has n, :mentions
# has n, :mentioned_statuses, :through => :mentions, :class_name => 'Status', :child_key => [:user_id], :remote_name => :status

# Status ---------------------------
# property :id, Serial
# property :text, String, :length => 140
# property :created_at, DateTime

# belongs_to :recipient, :class_name => "User", :child_key => [:recipient_id]
# belongs_to :user
# has n, :mentions
# has n, :mentioned_users, :through => :mentions, :class_name => 'User', :child_key => [:user_id]

# Relationship ---------------------
# property :user_id, Integer, :key => true
# property :follower_id, Integer, :key => true

# belongs_to :user, :child_key => [:user_id]
# belongs_to :follower, :class_name => "User", :child_key => [:follower_id]

# Mention --------------------------
# property :id, Serial

# belongs_to :user
# belongs_to :status



# 1)
# If you want to create a composite primary key, 
# you should call the primary_key method with an array of column symbols.

# http://sequel.rubyforge.org/rdoc/files/doc/schema_modification_rdoc.html

# 2)
# :class -------------
#    If the class of the association can not be guessed directly by looking at the association name, 
#    you need to specify it via the :class option.
# Source: http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html

# :left_key ---------- (located in current table)
#    FOREIGN KEY in JOIN TABLE that points to current model's primary key, as a symbol. 
#    Defaults to :"#{self.name.underscore}_id". Can use an array of symbols for a composite key association.
# :left_primary_key -- (located in current table)
#    Column in current table that :left_key points to, as a symbol. 
#    Defaults to primary key of current table. 
#    Can use an array of symbols for a composite key association.

# right_key ---------- (located in current table)
#   FOREIGN KEY in JOIN TABLE that points to associated model's primary key, as a symbol. 
#   Defaults to :"#{name.to_s.singularize}_id". Can use an array of symbols for a composite key association.
# right_primary_key -- (located in associated table)
#   Column in associated table that :right_key points to, as a symbol.
#   Defaults to primary key of the associated table.
#   Can use an array of symbols for a composite key association.

# 3)
# Source: http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/Associations/ClassMethods.html

# :key
# Source: http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html
# The :key option must be used if the default column symbol that Sequel would use is not the correct column. For example:

# class Album
#   # Assumes :key is :artist_id, based on association name of :artist
#   many_to_one :artist
# end
# class Artist
#   # Assumes :key is :artist_id, based on class name of Artist
#   one_to_many :albums
# end

# However, if your schema looks like:

# Database schema:
#  artists            albums
#   :id   <----\       :id
#   :name       \----- :artistid # Note missing underscore
#                      :name
# Then the default :key option will not be correct. To fix this, you need to specify an explicit :key option:

# class Album
#   many_to_one :artist, :key=>:artistid
# end
# class Artist
#   one_to_many :albumst, :key=>:artistid
# end
