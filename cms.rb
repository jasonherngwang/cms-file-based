require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, escape_html: true
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_contents(file_path)
  contents = File.read(file_path)

  case File.extname file_path
  when ".txt"
    headers["Content-Type"] = "text/plain"
    contents
  when ".md"
    # headers["Content-Type"] = "text/html;charset=utf-8"
    render_markdown(contents)
  end
end

get "/" do
  @files = Dir[File.join(data_path, "*")]
           .select { |f| File.file? f }
           .map { |f| File.basename f }

  erb :index, layout: :layout
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])
  
  if File.file? file_path
    load_file_contents(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  file_path = File.join(data_path, + params[:filename])
  @content = File.read(file_path)
  
  erb :edit_file, layout: :layout
end

post "/:filename" do
  content = params[:content]
  file_path = File.join(data_path, + params[:filename])
  File.open(file_path, "w") do |f|
    f.write content
  end
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end