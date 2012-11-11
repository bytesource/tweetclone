require_relative "db/tables"

class User < Sequel::Model
  
  def self.find(identifier)
    u = first(:identifier => identifier)
    u = new(:identifier => identifier)
  end

  # Return those messages of user that are not direct messages.
  def query(user)
    # :recipient => nil ... don't show direct messages
    # http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html => dataset_methods
    # user.statuses_dataset.filter(:recipient => nil).limit(10).order(:created_at)
    user.statuses { |ds| ds.filter(:recipient => nil).limit(10).order(:created_at)}
    # "SELECT * FROM \"statuses\" 
    #    WHERE ((\"statuses\".\"user_id\" = 2) AND 
    #          (\"recipient\" IS NULL))
    #    ORDER BY \"created_at\" 
    #    LIMIT 10">
  end
  
  def displayed_statuses
    
    statuses = []
    statuses += self.query.all
   
    if @myself == @user 
      self.follows.each { |follows| statuses += query(follows).all }
    end
    
    statuses.sort! { |x, y| y.created_at <=> x.created_at }
    statuses[0..10]
  end
end

user1 = User.create
user2 = User.create
p user1.query(user2)
# "SELECT * FROM \"statuses\" WHERE (\"statuses\".\"user_id\" = 2)">




