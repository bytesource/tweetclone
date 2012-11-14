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
  String      :website
  String      :isbn
  Integer     :copies_sold
  Numeric     :replaygain
  Integer     :rating
  Date        :release_date
  Date        :record_date
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

# Source:
# http://sequel.rubyforge.org/rdoc/files/doc/validations_rdoc.html
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
      super  # calls Sequel::Model#validate
      errors.add(:name, 'cannot be empty')       if !name || name.empty?
      errors.add(:name, 'is already taken')      if name && new? && Album[:name=>name] # Album.first(:name => name)
      errors.add(:website, 'cannot be empty')    if !website || website.empty?
      errors.add(:website, 'is not a valid URL') unless website =~ /\Ahttps?:\/\//
    end
  end

  # You can call simple methods such as:

  class Album < Sequel::Model
    plugin :validation_helpers

    def validate  # overrides the former definition of Album#validate (former validations are gone)
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
  album  = Album.new(:name => "Top10", :debut_album => false, :active => true)
  # NOTE: #add_album would throw database error if any of the non-NULL columns
  #       (:name, :debut_album, :active) was not set:
  artist.add_album(album)  # Saves Album instance to database (**)
  p artist.albums

  album2  = Album.new(:name => "Top10", :debut_album => false, :active => true)
  p album2.valid?
  # => true
  p album2.errors
  # => {}

  begin
    artist.add_album(album2)  # saves Album instance to database (**), calls validations before #save
  rescue Sequel::ValidationFailed
    # Before save foreign key of album2 gets set to primary key of artist.
    # Now 'album2' has both the same album name ("Top10") and foreign key value (1) as 'album' which has already
    # been saved to the database. Thus validates_unique([:name, :artist_id]) fails.
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
      # Block gets passed the dataset of all album rows.
      # Allows to further scope the uniqueness constraint.
      # Here: Only the names of albums with column :active == true are checked for uniqueness
      validates_unique(:name){|ds| ds.where(:active)}
    end
  end

  # Options
  # Unlike the other validations, the options hash for validates_unique only checks for two options:
  puts ":message" #          (String or Proc)   The message to use
  puts ":only_if_modified" # (Boolean)          Only check the uniqueness if the object is new or one of the columns has been modified.


  puts "validation_helpers Options"

  puts ":message" #         (String or Proc)   Overrides the default validation message.
  puts ":allow_nil" #       (Boolean)          Skips the validation if the attribute value is nil or if the attribute is not present.
  #                                            commonly used when you have a validates_presence method already on the attribute,
  #                                            and don't want multiple validation errors for the same attribute:
  class Album < Sequel::Model
    def validate
      validates_presence :copies_sold
      validates_integer :copies_sold, :allow_nil=>true # skips validation of :copies_sold is nil
    end
  end

  puts ":allow_blank" #     (Boolean)          Skips validation for all blank values, not just nil (as in :allow_nil)
  class Album < Sequel::Model
    def validate
      validates_format /\Ahttps?:\/\//, :website, :allow_blank=>true
    end
  end

  a = Album.new
  a.website = ''
  p a.valid?  # should return 'true', but returned 'false'
  p a.errors  # should be empty, but returned {:website=>["is invalid"]}

  puts ":allow_missing" #   (Boolean)          Checks if the attribute is present in the model instance's values hash.


  puts "Conditional Validation"
  # There's no special syntax you have to use for conditional validations.
  # Just handle conditionals the way you would in other ruby code.


  puts "Default Error Messages"
  # These are the default error messages for all of the helper methods in validation_helpers:

  # :exact_length
  # => is not #{arg} characters

  # :format
  # => is invalid

  # :includes
  # => is not in range or set: #{arg.inspect}

  # :integer
  # => is not a number

  # :length_range
  # => is too short or too long

  # :max_length
  # => is longer than #{arg} characters

  # :min_length
  # => is shorter than #{arg} characters

  # :not_string
  # => is not a valid #{schema_type}

  # :numeric
  # => is not a number

  # :type
  # => is not a #{arg}

  # :presence
  # => is not present

  # :unique
  # => is already taken


  puts "Modifying the Default Options"

  # All of the default options are stored in the Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS hash.
  # You just need to modify that hash to change the default options.
  # One way to do that is to use merge! to update the hash:

  Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS.merge!(
    :presence   => {:message => 'cannot be empty'},
    :includes   => {:message => 'invalid option', :allow_nil=>true},
    :max_length => {:message => lambda{|i| "cannot be more than #{i} characters"}, :allow_nil => true},
    :format     => {:message => 'contains invalid characters',                     :allow_nil => true})


    puts "Custom Validations"

    # Inside the #validate method, you can add your own validations by
    # ADDING TO THE INSTANCE'S ERRORS using #errors.add whenever an attribute is not valid:
    class Album < Sequel::Model
      def validate
        super
        errors.add(:release_date, 'cannot be before record date') if release_date < record_date
      end
    end

    puts "Custom validations that can be reused in ALL MODELS."

    # Example 1
    class Sequel::Model # base class
      def validates_after(col1, col2)
        errors.add(col1, "cannot be before #{col2}") if send(col1) < send(col2) # use #send because 'col1', 'col2' are passed as keywords
      end
    end

    class Album < Sequel::Model
      def validate
        super
        validates_after(:release_date, :record_date) #  checks that release date comes after record date
      end
    end

    # Example 2
    class Sequel::Model
      def self.string_columns
        @string_columns ||= columns.reject{ |c| db_schema[c][:type] != :string }
      end

      def validate  # validates_format is called in child class if super is added to first line of #validate
        super
        validates_format(/\A[^\x00-\x08\x0e-\x1f\x7f\x81\x8d\x8f\x90\x9d]*\z/,
                         model.string_columns,  # Album.model => Album [self.string_columns does not work: undefined method `string_columns' for #<Album...]
                         :message=>"contains invalid characters")
      end
    end

    class Album < Sequel::Model
      def validate
        super # Important! => calls #validates_format
        validates_presence :name
      end
    end

    p Album.string_columns
    # => [:name, :alt_name, :website, :isbn]
    p Album.db_schema
    # {:id=>{:oid=>23, :db_type=>"integer", :default=>"nextval('albums_id_seq'::regclass)", :allow_null=>false, :primary_key=>true, :type=>:integer, :ruby_default=>nil},
    #  :name=>{:oid=>25, :db_type=>"text", :default=>nil, :allow_null=>false, :primary_key=>false, :type=>:string, :ruby_default=>nil},
    #  :alt_name=>{:oid=>25, :db_type=>"text", :default=>nil, :allow_null=>true, :primary_key=>false, :type=>:string, :ruby_default=>nil},
    # ...
    # }
    p Album.columns
    # [:id, :name, :alt_name, :debut_album, :website, :isbn, :copies_sold, :replaygain, :rating,
    #  :release_date, :record_date, :upc, :active, :artist_id]
    p Album.model  # this is a class method, how can it be called within #validate?
    # => Album

    a = Album.new
    p a.valid?
    p a.errors


    puts "Sequel::Model::Errors"
    # Sequel::Model::Errors is a subclass of Hash with a few special methods,
    # the most common of which are described here:
    puts "add"
    # Adds error messages for a given column.
    # -- Takes the column symbol as the first argument and the
    # -- error message as the second argument:
    # errors.add(:name, 'is not valid')

    puts "on"
    # Determines if there were any errors on a given attribute.
    # Usually used after validation has been completed.
    # -- Takes the column value, and
    # -- Returns an array of error messages if there were any, or nil if not:

    # errors.on(:name)
    # Don't care about validating the release date if there were validation errors for the record date.
    # validates_integer(:release_date) if !errors.on(:record_date)

    puts "full_messages"
    # Commonly called after validation to get a list of error messages to display to the user.
    # -- Returns an ARRAY OF ALL ERROR MESSAGES FOR THE OBJECT.
    album.errors
    # => {:name=>["cannot be empty"]}
    album.errors.full_messages
    # => ["name cannot be empty"]

    puts "count"
    # -- Returns the TOTAL number of error messages in the errors.
    album.errors.count # => 1

end
DB.drop_table(:albums, :artists) # Parent table must be deleted last, as child tables refer to it




# (**)
puts "add_association(object_to_associate) (e.g. add_album) [one_to_many and many_to_many]"
# http://sequel.rubyforge.org/rdoc/files/doc/association_basics_rdoc.html
# The add_association method associates the passed object to the current object.
# 1) one_to_many associations:
#    -- Sets the foreign key of the associated object to the primary key value of the current object, and
#    -- SAVES the associated object.
# 2) many_to_many associations:
#    -- Inserts a row into the join table with the
#    -- foreign keys set to the primary key values of the current and associated objects.
# Note that the singular form of the association name is used in this method.

puts "association=(object_to_associate) (e.g. artist=) [many_to_one and one_to_one]"
# The association= method sets up an association of the passed object to the current object.
# 1) For many_to_one associations:
#    -- Sets the FOREIGN KEY for the CURRENT object to point to the associated object's primary key.
#       @album.artist = @artist  # album = current object, artist = associated object
#    -- DOES NOT SAVE the CURRENT object.
# 2) one_to_one associations:
#    -- Sets the FOREIGN KEY of the ASSOCIATED object to the primary key value of the current object.
#    -- Does SAVE the ASSOCIATED object.







