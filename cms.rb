require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'random'
end

def main_env_path
  File.expand_path("../data", __FILE__)
end

def content_from_main_system_file(filename)
  file = File.join(main_env_path, filename)
  File.read(file)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(md_file)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(md_file)
end

def load_file_content(file_path)
  content = File.read(file_path)
  if File.extname(file_path) == '.txt'
      headers['Content-Type'] = 'text/plain'
      content
  elsif File.extname(file_path) == '.md'
    erb render_markdown(content)
  else
    content
  end
end

def new_document(name)
  File.new(File.join(data_path, name), 'w')
end

# Go to the main index
get '/' do
  pattern = File.join(data_path, '*')
  @cmsfiles = Dir[pattern].map do |path|
    File.basename(path)
  end

  erb :index, layout: :layout
end

# Render a form for creating a new document
get '/new_document' do
  erb :new, layout: :layout
end

# Create the new document
post '/create_document' do
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
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_file_content(file_path)    
  else
    redirect not_found
  end
end

# Go to the page for editing
get '/:filename/edit' do
  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)

  erb :edit_document, layout: :layout
end

# Update a file
post '/:filename' do
  file_path = File.join(data_path, params[:filename])

  change = params[:content]
  File.open(file_path, 'w+') { |file| file.write(change) }

  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end

# Delete a document
post '/:filename/delete' do
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
