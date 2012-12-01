%w(sinatra ./tweetclone).each { |lib| require lib}
run Sinatra::Application
