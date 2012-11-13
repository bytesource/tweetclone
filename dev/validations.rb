require 'sequel'
require 'logger'
# Create database
# CREATE DATABASE validations WITH ENCODING 'UTF-8'

DB = Sequel.connect(ENV['DATABASE_URL'] ||'postgres://postgres:blablabla@localhost/validations')

# Logging SQL Queries
DB.loggers << Logger.new($stdout)


# Parent table (the one other tables point their foreign key to) must be created first.
DB.create_table? :artists do
  primary_key :id
  String      :name,       :null => false
end

DB.create_table? :albums do
  primary_key :id
  String      :name,        :null => false, :unique => true
  String      :alt_name
  Boolean     :debut_album, :null => false
  String      :website,     :null => false
  String      :isbn
  Integer     :copies_sold
  Numeric     :replaygain
  Integer     :rating
  DateTime    :release_date  # better: Date
  DateTime    :record_date   # better: Date
  Integer     :upc           # universal product code
  Boolean     :active,       :null => false
  foreign_key :artist_id, :artists, :key => :id, :on_update => :cascade, :on_delete => :cascade
end

class Artist < Sequel::Model
  one_to_many :albums
end

class Album < Sequel::Model
  many_to_one :artist
end

DB.transaction do

  puts "valid? and validate"
  puts "================================"

  # http://sequel.rubyforge.org/rdoc/files/doc/validations_rdoc.html

  # Validations will only be run if you call #save on the model object,
  # or another model method that calls #save.
  # For example, the ::create class method instantiates a new instance of the model,
  # and then calls #save, so it validates the object.
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
  p Album.new.valid?              # false
  p Album.new(:name=>'').valid?   # false
  p Album.new(:name=>'RF').valid? # true

  # NOTE:
  # #save calls #validate, and so does #valid? as it seems
  # (otherwise how could it determine if an instance is valid?)

  # If the valid? method returns false, you can call the errors method to get an instance of Sequel::Model::Errors describing the errors on the model:

  a = Album.new
  # => #<Album @values={}>
  a.valid?
  # => false
  p a.errors
  # => {:name=>["cannot be empty"]}

  # NOTE
  # Calling the errors method before the valid? method will result in an errors being empty:
  Album.new.errors
  # => {}
  # So just remember that you shouldn't check errors until after you call valid?.


  puts "validation_helpers"
  puts "================================"

  # Sequel ships with a plugin called validation_helpers that handles most basic validation needs.
  # So instead of specifying validations like this:

  class Album < Sequel::Model
    def validate
      super
      errors.add(:name, 'cannot be empty')       if !name || name.empty?
      errors.add(:name, 'is already taken')      if name && new? && Album[:name=>name] # Album.first(:name => name)
      errors.add(:website, 'cannot be empty')    if !website || website.empty?
      errors.add(:website, 'is not a valid URL') unless website =~ /\Ahttps?:\/\//
    end
  end

  # You can call simple methods such as:

  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      super
      validates_presence [:name, :website]   # with default error message
      validates_unique   :name               # with default error message
      validates_format   /\Ahttps?:\/\//, :website, :message => 'is not a valid URL'
    end
  end

  # Function parameters
  # 1) All except validates_format:
  #    (atts, opts={})
  #       atts = :col_name or [:col_name1, :col_name2, ...]
  #       opts = option hash with keys such as :message
  # 2) validates_format, validates[...length], validates_includes
  #    (arg, atts, opts={})
  #       arg = additional first argument
  # example: regular expression describing the format in validates_format
  # 2) validates_unique: find information in section 'validates_unique'


  puts "validates_presence"

  # #validates_presence is safe to use on boolean columns
  # where you want to ensure that either true or false is used, but not NULL:
  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      validates_presence [:name, :website, :debut_album]
    end
  end

  puts "validates_format"

  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      validates_format /\A\d\d\d-\d-\d{7}-\d-\d\z/, :isbn
      validates_format /\a[0-9a-zA-Z:' ]+\z/, :name
    end
  end


  puts "validates_exact_length"   # Checks that: value == length
  puts "validates_min_length"     # Checks that: value >= length
  puts "validates_max_length"     # Checks that: value <= length`
  puts "validates_length_range"   # Checks that: value in Ruby Range or object that responds to include?

  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      validates_exact_length 17, :isbn
      validates_min_length 3, :name
      validates_max_length 100, :name
      validates_length_range 3..100, :name # First argument: Ruby Range or object that responds to include?
    end
  end


  puts "validates_integer"        # Checks that: value is Integer (by calling Kernel.Integer)
  puts "validates_numeric"        # Checks that: value is Float   (by calling Kernel.Float)

  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      validates_integer :copies_sold
      validates_numeric :replaygain
    end
  end


  puts "validates_includes"       # Checks that: value is included in collection

  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      validates_includes [1, 2, 3, 4, 5], :rating   # First argument: any object that responds to #include?
    end
  end


  puts "validates_type"           # Checks that: value is an instance of the class specified in the first argument

  # Note the class can be specified as either:
  # -- the class itself,
  # -- a string
  # -- a symbol with the class name
  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      validates_type String, [:name, :website]
      # validates_type :Artist, :artist
    end
  end


  puts "validates_not_string"

  # NOTE:
  # Sequel::Model::raise_on_typecast_failure
  # Whether to raise an error when unable to typecast data for a column (default: true).
  # source: http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/ClassMethods.html#attribute-i-raise_on_typecast_failure

  # For WEB APPLICATIONS, you usually want to USE:
  # -- raise_on_typecast_failure = FALSE,
  #    so that you can accept all of the input without raising an error, and then use
  # -- validates_not_string
  #    to present the user with all error messages.

  # Without the setting, if the user submits any invalid data, Sequel will immediately raise an error.
  # validates_not_string is helpful because it allows you to check for typecasting errors on NON-string columns,
  # and provides a good default error message stating that the attribute is not of the expected type.
  class Album < Sequel::Model
    self.raise_on_typecast_failure = false
    plugin :validation_helpers

    def validate
      validates_not_string [:release_date, :record_date]
    end
  end

  album = Album.new
  album.release_date = 'banana'
  p album.release_date
  # => banana
  # Assigned 'banana' to release_date, but added error to #errors
  # Note: album has not yet been saved to the database, so the assignment does not do any harm.
  album.record_date = '2012-11-12'
  p album.record_date
  # => 2012-11-12 00:00:00 +0800
  p album.valid?
  # => false
  # NOTE: Don't forget to call #valid? before checking #error, otherwise #errors will just return an empty hash!
  p album.errors
  # => {:release_date=>["is not a valid datetime"]}


  Sequel::Model.raise_on_typecast_failure = true
  puts "validates_unique"



  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      # List of column symbols:
      # Separate validation for each of the columns
      # => Probably not what you want in this case
      #    (Albums can have the same name as long as they are from different artists)
      validates_unique(:name, :artist_id)
    end
  end


  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      # Array of column symbols:
      # Unique validation for the COMBINATION of the columns
      # => Check that name is unique with regard to the same artist_id
      #    (Don't let one artist have two albums with the same name.)
      validates_unique([:name, :artist_id])
    end
  end

  artist = Artist.create(:name => "Stefan")
  album  = Album.new(:name => "Top10", :website => "http://www.sovonex.com", :debut_album => false, :active => true)
  # NOTE: Would throw database error if any of non-NULL columns (:name, :website, :debut_album, :active) was not set.
  artist.add_album(album)  # saves Album instance to database (**)
  p artist.albums
  
  album2  = Album.new(:name => "Top10", :website => "http://www.sovonex.de", :debut_album => false, :active => true)
  p album2.valid?
  album2.artist_id = 1
  p album2.valid?
  p album2.errors
  # {[:name, :artist_id]=>["is already taken"]}
  begin 
  artist.add_album(album2)  # saves Album instance to database (**)
  rescue Sequel::ValidationFailed
    puts "Validation failed: Album name for this artist #{album2.errors[[:name, :artist_id]][0]}"
  end
  # => Validation failed: Album name for this artist is already taken
  
  
  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      # Mix and match list of column names with array(s) of column names
      validates_unique(:upc, [:name, :artist_id])
    end
  end

  class Album < Sequel::Model
    plugin :validation_helpers

    def validate
      validates_unique(:name){|ds| ds.where(:active)}
    end
  end


end
DB.drop_table(:albums, :artists) # Parent table must be deleted last, as child tables refer to it




# (**)
puts "add_association(object_to_associate) (e.g. add_album) [one_to_many and many_to_many]"
# http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html
# The add_association method associates the passed object to the current object. 
# 1) one_to_many associations:
#    -- sets the foreign key of the associated object to the primary key value of the current object, and
#    -- SAVES the associated object. 
# 2) many_to_many associations:
#    -- inserts a row into the join table with the 
#    -- foreign keys set to the primary key values of the current and associated objects. 
# Note that the singular form of the association name is used in this method.









