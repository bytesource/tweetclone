require_relative "db/tables"

class User < Sequel::Model
  
  def self.find(identifier)
    u = first(:identifier => identifier)
    u = new(:identifier => identifier)
  end

  # Return those messages of user that are not direct messages.
  def query(user)
    # :recipient => nil ... don't show direct messages
    user.statuses.filter(:recipient => nil).limit(10).order(:created_at).all
  end
  
  def displayed_statuses
    
    statuses = []
    statuses += self.query
   
    if @myself == @user 
      self.follows.each { |follows| statuses += query }
    end
    
    statuses.sort! { |x, y| y.created_at <=> x.created_at }
    statuses[0..10]
  end
end


