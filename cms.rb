require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'random'
end

def main_env_data_path
  File.expand_path("../data", __FILE__)
end

def content_from_main_system_file(filename)
  file = File.join(main_env_data_path, filename)
  File.read(file)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def config_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/config", __FILE__)
  else
    File.expand_path("../config", __FILE__)
  end
end

def yml_file?(filename)
  File.extname(filename) == '.yml'
end

def retrieve_filepath(filename)
  if yml_file?(filename)
    File.join(config_path, filename)
  else
    File.join(data_path, filename)
  end
end

def render_markdown(md_file)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(md_file)
end

def load_file_content(file_path)
  content = File.read(file_path)
  case File.extname(file_path)
  when ".txt", '.yml'
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

def new_document(name)
  File.new(File.join(data_path, name), 'w')
end

def signed_in?
  session[:signed_in] ? true : false
end

def redirect_to_index_unless_signed_in
  unless signed_in?
    session[:message] = 'You must be signed in to do that.'
    redirect '/'
  end
end

# Go to the main index
get '/' do
  pattern = File.join(data_path, '*')
  @cmsfiles = Dir[pattern].map do |path|
    File.basename(path)
  end

  users_filepath = File.join(config_path, 'users.yml')
  @users_file = File.basename(users_filepath)

  erb :index, layout: :layout
end

# Render a form for creating a new document
get '/new_document' do
  redirect_to_index_unless_signed_in
  erb :new, layout: :layout
end

# Create the new document
post '/create_document' do
  redirect_to_index_unless_signed_in
  new_name = params[:doc_name]
  if new_name.empty?
    session[:message] = 'A name is required.'
    status 422
    erb :new, layout: :layout
  else
    new_document(new_name)

    session[:message] = "#{new_name} was created."

    redirect '/'
  end
end

# User sign in
get '/user/sign_in' do
  erb :sign_in, layout: :layout
end

# Sign the user in
post '/user/sign_in' do
  @username = params[:username]
  password = params[:password]

  if @username == 'admin' && password == 'secret'
    session[:signed_in] = true
    session[:username] = @username
    session[:message] = 'Welcome!'
    redirect '/'
  else
    session[:message] = 'Invalid Credentials'
    status 422
    erb :sign_in, layout: :layout
  end
end

# Sign the user out
post '/user/sign_out' do
  session[:signed_in] = false
  session.delete(:username)
  session[:message] = 'You have been signed out.'
  redirect '/'
end

# View a document's page
get '/:filename' do
  filename = params[:filename]
  file_path = retrieve_filepath(filename)

  if File.file?(file_path)
    load_file_content(file_path)    
  else
    redirect not_found
  end
end

# Go to the page for editing
get '/:filename/edit' do
  redirect_to_index_unless_signed_in
  @filename = params[:filename]
  file_path = retrieve_filepath(@filename)

  @content = File.read(file_path)

  erb :edit_document, layout: :layout
end

# Update a file
post '/:filename' do
  redirect_to_index_unless_signed_in

  filename = params[:filename]
  file_path = retrieve_filepath(filename)

  change = params[:content]
  File.open(file_path, 'w+') { |file| file.write(change) }

  session[:message] = "#{filename} has been updated."
  redirect '/'
end

# Delete a document
post '/:filename/delete' do
  redirect_to_index_unless_signed_in
  filename = params[:filename]
  file_path = File.join(data_path, filename)

  if File.file?(file_path)
    File.delete(file_path)
    session[:message] = "#{filename} was deleted."
    redirect '/'
  else
    session[:message] = "No file #{filename} to delete."
    erb :index, layout: :layout
  end
end

not_found do
  path = request.path
  filename = File.basename(path)
  session[:message] = "#{filename} does not exist."
  redirect '/'
end
