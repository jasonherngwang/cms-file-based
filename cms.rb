require "yaml"
require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "bcrypt"

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

def load_user_credentials
  filepath = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  Psych.load_file(filepath)
end

def valid_credentials?(user, password)
  credentials = load_user_credentials

  if credentials.key?(user)
    bcrypt_password = BCrypt::Password.new(credentials[user])
    bcrypt_password == password
  else
    false
  end
end

def error_for_signin(user, password)
  if user.empty? || password.empty?
    "Username and/or password cannot be empty."
  else
    "Invalid Credentials."
  end
end

def require_signin
  unless signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/users/signin"
  end
end

helpers do
  def signed_in?
    session.key?(:user)
  end
end

get "/users/signin" do
  erb :signin, layout: :layout
end

post "/users/signin" do
  user = params[:user]
  password = params[:password]

  if valid_credentials?(user, password)
    session[:user] = user
    session[:message] = "Welcome!"

    redirect "/"
  else
    error = error_for_signin(user, password)
    session[:message] = error
    status 422

    erb :signin, layout: :layout
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
  @user = session[:user] if signed_in?

  erb :index, layout: :layout
end

get "/new" do
  require_signin

  erb :new_document, layout: :layout
end

post "/new" do
  require_signin

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
  require_signin

  file_path = File.join(data_path, params[:filename])
  @content = File.read(file_path)
  
  erb :edit_document, layout: :layout
end

post "/:filename" do
  require_signin

  content = params[:content]
  file_path = File.join(data_path, params[:filename])
  File.open(file_path, "w") do |f|
    f.write content
  end
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_signin

  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)
  session[:message] = "#{params[:filename]} was deleted."
  redirect "/"
end