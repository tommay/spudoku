require_relative "spudoku"

#map "/favicon.ico" do
#  run Rack::File.new("public")
#end

run Sinatra::Application
