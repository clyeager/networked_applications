require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'psych'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def render_markdown(text)
   markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
   markdown.render(text)
end

def load_content(file_path)
  if file_path.match('.md')
    erb render_markdown(File.read(file_path))
  else
    headers["Content-Type"] = "text/plain"
    File.read(file_path)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def check_credentials(user, password)
  if ENV["RACK_ENV"] == "test"
    file_path = File.expand_path("../test/users.yml", __FILE__)
    admin = Psych.load_file(file_path)
    BCrypt::Password.new(admin[user]) == password
  else
    file_path = File.expand_path("../users.yml", __FILE__)
    all_users = Psych.load_file(file_path)
    BCrypt::Password.new(all_users[user]) == password
  end
end

def signed_in?
  session[:username]
end

def require_signed_in_user
  unless signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
  File.basename(path)
  end
  erb :index
end

get "/users/signin" do
  erb :sign_in
end

post "/users/signin" do
  if check_credentials(params[:username], params[:password])
    session[:username] = params[:username]

    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :sign_in
  end
end

post "/users/signout" do
  session[:username] = nil
  session[:message] = "You have been signed out"
  redirect "/"
end

get "/new" do
  require_signed_in_user

  erb :new
end

post "/create" do
  require_signed_in_user

  filename = params[:filename].to_s

  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{filename} was created."
    redirect "/"
  end
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    load_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  @filename = params[:filename]
  file_path = File.join(data_path, params[:filename])
  @content = File.read(file_path)

  erb :edit
end

post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted"

  redirect "/"
end