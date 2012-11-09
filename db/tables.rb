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

DB.create_table! :users do
  primary_key :id
  String      :email,          :size => 255
  String      :nickname,       :size => 255
  String      :formatted_name, :size => 255
  String      :provider,       :size => 255
  String      :identifier,     :size => 255
  String      :phote_url,      :size => 255
  String      :location,       :size => 255
  String      :description,    :size => 255
end

DB.create_table! :statuses do
  primary_key :id
  String      :text,           :size => 140
  DateTime    :created_at
end

DB.create_table! :relationships do
  Integer :user_id
  Integer :follower_id
  primary_key [:user_id, :follower_id]   # 1)
end

DB.create_table! :mentions do
  Integer :user_id
  Integer :status_id
  primary_key [:user_id, :status_id]
end



# ASSOCIATIONS ===============================

class User < Sequel::Model
  one_to_many  :statuses      
  one_to_many  :direct_messages, :class => :Status
  many_to_many :relationships,   :class => self,   :join_table => :relationships, :right_key => :follower_id  # 2)
  many_to_many :followers,       :class => self,   :join_table => :relationships, :right_key => :follower_id  # :left_key is default :user_id
  many_to_many :follows,         :class => self,   :join_table => :relationships, :right_key => :user_id, :left_key => :follower_id
  many_to_many :mentions,        :class => :Status, :join_table => :mentions, :left_key => :user_id, :right_key => :status_id
  many_to_many :mentioned_statuses,   
                                 :class => :Status, :join_table => :mentions, :left_key => :user_id, :right_key => :status_id
end


class Status < Sequel::Model
  many_to_one :recipient, :class => :User
  many_to_one :user
  many_to_many :mentions, :class => :User, :join_table => :mentions, :left_key => :status_id, :right_key => :user_id
  many_to_many :mentioned_users, :class => :User, :join_table => :mentions, :left_key => :status_id, :right_key => :user_id
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


