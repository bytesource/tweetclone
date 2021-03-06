# Taken from "Cloning Internet Applications with Ruby"

require 'data_mapper'

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
  has n, :direct_messages,    :class_name => "Status"
  has n, :relationships
  has n, :followers,          :through => :relationships, :class_name => "User", :child_key => [:user_id]
  has n, :follows,            :through => :relationships, :class_name => "User", :remote_name => :user, :child_key => [:follower_id]
  has n, :mentions
  has n, :mentioned_statuses, :through => :mentions, :class_name => 'Status', :child_key => [:user_id], :remote_name => :status
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
end

class Relationship
  include DataMapper::Resource

  property :user_id, Integer, :key => true
  property :follower_id, Integer, :key => true

  belongs_to :user, :child_key => [:user_id]
  belongs_to :follower, :class_name => "User", :child_key => [:follower_id]
end

class Mention
  include DataMapper::Resource

  property :id, Serial

  belongs_to :user
  belongs_to :status
end
