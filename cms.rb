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
  # In case the file does not have an extension.
  when ".txt", ""
    headers["Content-Type"] = "text/plain"
    contents
  when ".md"
    # headers["Content-Type"] = "text/html;charset=utf-8"
    render_markdown(contents)
  end
end

def error_for_signin(user, password)
  if user.empty? || password.empty?
    "Username and/or password cannot be empty."
  elsif user != "admin" || password != "secret"
    "Invalid Credentials."
  end
end

helpers do
  def logged_in?
    !!session[:user]
  end
end

before do
  if request.path == "/new" || 
    request.path =~ /\/.+\/(delete|edit)/

    unless session[:user]
      redirect "/users/signin"
    end
  end
end

get "/users/signin" do
  erb :signin, layout: :layout
end

post "/users/signin" do
  user = params[:user].to_s.strip
  password = params[:password].to_s

  error = error_for_signin(user, password)
  if error
    session[:message] = error
    status 422

    erb :signin, layout: :layout
  else
    session[:user] = user
    session[:message] = "Welcome!"

    redirect "/"
  end
end

post "/users/signout" do
  session.delete(:user)
  session[:message] = "You have been signed out."

  redirect "/"
end

get "/" do
  @files = Dir[File.join(data_path, "*")]
           .select { |f| File.file? f }
           .map { |f| File.basename f }
  @user = session[:user] if logged_in?

  erb :index, layout: :layout
end

get "/new" do
  erb :new_document, layout: :layout
end

post "/new" do
  filename = params[:filename]

  if filename.empty?
    session[:message] = "A name is required."
    status 422
    erb :new_document, layout: :layout
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{filename} was created."

    redirect "/"
  end
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
  file_path = File.join(data_path, params[:filename])
  @content = File.read(file_path)
  
  erb :edit_document, layout: :layout
end

post "/:filename" do
  content = params[:content]
  file_path = File.join(data_path, params[:filename])
  File.open(file_path, "w") do |f|
    f.write content
  end
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)
  session[:message] = "#{params[:filename]} was deleted."
  redirect "/"
end