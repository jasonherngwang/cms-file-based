require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir[root + "/data/*"]
    .select { |f| File.file? f }
    .map { |f| File.basename f }

    erb :index, layout: :layout
end