require_relative '../model'


user1 = User.first(:nickname => "Stefan") || User.create(:nickname => "Stefan")
# user2 = User.create
# p user1.query(user2)
# "SELECT * FROM \"statuses\" WHERE (\"statuses\".\"user_id\" = 2)">
# p user1.relationships
# SELECT "users".* FROM "users" 
#    INNER JOIN "relationships" ON (("relationships"."follower_id" = "users"."id") AND 
#                                   ("relationships"."user_id" = 5))

p user1.id
# => 
puts "user.followers:"
p user1.followers
# SELECT "users".* FROM "users" 
#   INNER JOIN "relationships" 
#     ON (("relationships"."follower_id" = "users"."nickname") 
#     AND ("relationships"."user_id" = 'Stefan'))   # why not use 'WHERE' here?

puts "user.follows:"
p user1.follows
# SELECT "users".* FROM "users" 
#   INNER JOIN "relationships" 
#     ON (("relationships"."user_id" = "users"."nickname") 
#     AND ("relationships"."follower_id" = 'Stefan'))

puts "friends of users"
p user1.friends

# =====================
# Querying friendship relation (A follows B, B follows A)
# Correct as per Stackoverflow: http://stackoverflow.com/questions/5113195/get-followers-twitter-like-using-mysql
# SELECT COUNT(me.A) FROM social AS me 
#    INNER JOIN social AS you ON me.A = you.B AND me.B = you.A
# WHERE me.A = 1

puts "Statuses ======================="
status = Status.create(:text => "first text")
p status
# => #<Status @values={:id=>5, :recipient=>nil, :owner=>nil, :text=>"first text", :created_at=>2012-11-20 12:18:16 +0800}>
p status.recipient


id = 1
puts "message count"
p Status.filter(:owner_id => id).exclude(:recipient_id => nil)
# SELECT * FROM \"statuses\" WHERE ((\"owner_id\" = 1) AND (\"recipient_id\" IS NOT NULL))


puts "count at end of association"
p "Count = #{user1.statuses.count}"

puts "includes?"
p user1.statuses.include?(user1)






