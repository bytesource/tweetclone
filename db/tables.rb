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
DB.create_table? :users do
  primary_key :id
  String      :email,          :size => 255# , :null => false
  String      :nickname,       :size => 255# , :null => false, :unique => true
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
  foreign_key :recipient,   :users, :key => :id, :on_update => :cascade, :on_delete => :cascade   # who is the recipient (for direct messages)
  foreign_key :user_id,     :users, :key => :id, :on_update => :cascade, :on_delete => :cascade   # who is the sender
  String      :text,           :size => 140, :null => false
  DateTime    :created_at,                   :null => false
end

DB.create_table? :relationships do # join table user <=> user
  Integer :user_id
  Integer :follower_id
  primary_key [:user_id, :follower_id]   # 1)
end

DB.create_table? :mentions do     # join table user <=> status
  Integer :user_id
  Integer :status_id
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
  one_to_many  :statuses      
  one_to_many  :direct_messages, :class => :Status
  many_to_many :relationships,   :class => self,    :join_table => :relationships, :right_key => :follower_id  # 2)
  many_to_many :followers,       :class => self,    :join_table => :relationships, :right_key => :follower_id  # :left_key is default :user_id
  many_to_many :follows,         :class => self,    :join_table => :relationships, :right_key => :user_id, :left_key => :follower_id
  many_to_many :mentions,        :class => :Status, :join_table => :mentions, :left_key => :user_id, :right_key => :status_id
  many_to_many :mentioned_statuses,   
                                 :class => :Status, :join_table => :mentions, :left_key => :status_id, :right_key => :user_id
end


class Status < Sequel::Model
  many_to_one  :recipient,       :class => :User
  many_to_one  :user
  many_to_many :mentions,        :class => :User, :join_table => :mentions, :left_key => :status_id, :right_key => :user_id
  many_to_many :mentioned_users, :class => :User, :join_table => :mentions, :left_key => :user_id, :right_key => :status_id
  
  def after_create
    self.created_at ||= Time.now
    super
  end
end


# Datamapper Associations:

# User -----------------------------
# has n, :statuses
# has n, :direct_messages,    :class_name => "Status"
# has n, :relationships
# has n, :followers,          :through => :relationships, :class_name => "User", :child_key => [:user_id]
# has n, :follows,            :through => :relationships, :class_name => "User", :remote_name => :user, :child_key => [:follower_id]
# has n, :mentions
# has n, :mentioned_statuses, :through => :mentions, :class_name => 'Status', :child_key => [:user_id], :remote_name => :status

# Status ---------------------------
# belongs_to :recipient, :class_name => "User", :child_key => [:recipient_id]
# belongs_to :user
# has n, :mentions
# has n, :mentioned_users, :through => :mentions, :class_name => 'User', :child_key => [:user_id]

# Relationship ---------------------
# belongs_to :user, :child_key => [:user_id]
# belongs_to :follower, :class_name => "User", :child_key => [:follower_id]

# Mention --------------------------
# belongs_to :user
# belongs_to :status



# 1)
# If you want to create a composite primary key, 
# you should call the primary_key method with an array of column symbols.
# http://sequel.rubyforge.org/rdoc/files/doc/schema_modification_rdoc.html

# 2)`
# :class -------------
# If the class of the association can not be guessed directly by looking at the association name, 
# you need to specify it via the :class option.
# :left_key ----------
# foreign key in join table that points to current model's primary key, as a symbol. 
# Defaults to :"#{self.name.underscore}_id". Can use an array of symbols for a composite key association.
# right_key ----------
# foreign key in join table that points to associated model's primary key, as a symbol. 
# Defaults to :"#{name.to_s.singularize}_id". Can use an array of symbols for a composite key association.
# Source: http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html


