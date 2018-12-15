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
    render_markdown(content)
  end
end

# Go to the main index
get '/' do
  pattern = File.join(data_path, '*')
  @cmsfiles = Dir[pattern].map do |path|
    File.basename(path)
  end

  erb :index
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

  erb :edit_document
end

# Update a file
post '/:filename' do
  file_path = File.join(data_path, params[:filename])

  change = params[:content]
  File.open(file_path, 'w+') { |file| file.write(change) }

  session[:message] = "#{params[:filename]} has been updated."
  redirect '/'
end

not_found do
  path = request.path
  filename = File.basename(path)
  session[:message] = "#{filename} does not exist."
  redirect '/'
end
