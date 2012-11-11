# Create database
# CREATE DATABASE validations WITH ENCODING 'UTF-8'
DB = Sequel.connect(ENV['DATABASE_URL'] ||'postgres://postgres:blablabla@localhost/validations')

# Logging SQL Queries
DB.loggers << Logger.new($stdout)

DB.create_table! :albums do
  primary_key :id
  String      :name, :null => false
  Integer     :age
end

# http://sequel.rubyforge.org/rdoc/files/doc/validations_rdoc.html

# Validations will only be run if you call #save on the model object, 
# or another model method that calls #save. 
# For example, the ::create class method instantiates a new instance of the model, 
# and then calls # save, so it validates the object. 
# However, the ::insert class method is a dataset method that just inserts the raw hash into the database, 
# so it doesn't validate the object.

# Sequel::Model uses the #valid? method to check whether or not a model instance is valid. 
# The #validate method should be overridden to add validations to the model:

class Album < Sequel::Model
  def validate
    super
    errors.add(:name, 'cannot be empty') if !name || name.empty?
  end
end
Album.new.valid?              # false
Album.new(:name=>'').valid?   # false
Album.new(:name=>'RF').valid? # true

# If the valid? method returns false, you can call the errors method to get an instance of Sequel::Model::Errors describing the errors on the model:

a = Album.new
# => #<Album @values={}>
a.valid?
# => false
a.errors
# => {:name=>["cannot be empty"]}