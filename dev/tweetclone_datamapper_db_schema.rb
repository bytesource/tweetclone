# CREATE DATABASE tweetclone WITH ENCODING 'UTF-8'
require 'sequel'
require 'logger'

# CONNECTION ================================
DB = Sequel.connect(ENV['DATABASE_URL'] ||'postgres://postgres:password@localhost/tweetclone')

# Logging SQL Queries
DB.loggers << Logger.new($stdout)


# TABLES ===================================
Sequel.inflections do |inflect|
  inflect.irregular 'status', 'statuses'
end

DB.create_table? :users do
  String      :nickname,       :size => 255, :primary_key => true
  String      :email,          :size => 255, :null => false
  String      :formatted_name, :size => 255, :null => false
  String      :provider,       :size => 255, :null => false
  String      :identifier,     :size => 255, :null => false
  String      :phote_url,      :size => 255, :null => false
  String      :location,       :size => 255, :null => false
  String      :description,    :size => 255, :null => false
end

DB.create_table? :statuses do
  primary_key :id
  foreign_key :recipient,   :users, :key => :nickname, :type => String,
                            :on_update => :cascade, :on_delete => :set_null
  foreign_key :owner,       :users, :key => :nickname, :type => String,
                            :on_update => :cascade, :on_delete => :cascade
  String      :text,        :size => 140, :null => false
  DateTime    :created_at,  :null => false
end

DB.create_table? :relationships do
  foreign_key :user_id,     :users, :key => :nickname, :type => String,
                            :on_update => :cascade, :on_delete => :cascade
  foreign_key :follower_id, :users, :key => :nickname, :type => String,
                            :on_update => :cascade, :on_delete => :cascade
  primary_key [:user_id, :follower_id]
end

DB.create_table? :mentions do
  foreign_key :user_id,      :users, :key => :nickname, :type => String,
                             :on_update => :cascade, :on_delete => :cascade
  foreign_key :status_id,    :statuses, :key => :id,
                             :on_update => :cascade, :on_delete => :cascade
  primary_key [:user_id, :status_id]
end


# ASSOCIATIONS ===============================
class User < Sequel::Model
  one_to_many  :statuses
  one_to_many  :direct_messages, :class => :Status

  many_to_many :friends  # Friendship association: A follows B and B follows A
  many_to_many :followers,
               :class => self, :join_table => :relationships,
               :left_key => :user_id, :right_key => :follower_id
  many_to_many :follows,
               :class => self, :join_table => :relationships,
               :right_key => :user_id, :left_key => :follower_id
  many_to_many :mentions,
               :class => :Status, :join_table => :mentions,
               :left_key => :user_id, :right_key => :status_id
  many_to_many :mentioned_statuses,
               :class => :Status, :join_table => :mentions,
               :left_key => :status_id, :right_key => :user_id
end

User.unrestrict_primary_key

class Status < Sequel::Model
  many_to_one  :recipient,       :class => :User
  many_to_one  :user
  many_to_many :mentions,        :class => :User, :join_table => :mentions,
                                 :left_key => :status_id, :right_key => :user_id
  many_to_many :mentioned_users, :class => :User, :join_table => :mentions,
                                 :left_key => :user_id, :right_key => :status_id

  def after_create
    self.created_at ||= Time.now
    super
  end
end



user = User.find(:nickname => "me") || User.create(:nickname => "me")
p user.followers
# SELECT "users".* FROM "users"
#   INNER JOIN "relationships"
#     ON (("relationships"."follower_id" = "users"."nickname")
#     AND ("relationships"."user_id" = 'me'))   # why not use 'WHERE' here?

p user.follows
# SELECT "users".* FROM "users"
#   INNER JOIN "relationships"
#     ON (("relationships"."user_id" = "users"."nickname")
#     AND ("relationships"."follower_id" = 'me'))

