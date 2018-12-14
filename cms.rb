require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

root = File.expand_path("..", __FILE__ )

configure do
  enable :sessions
  set :session_secret, 'random'
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
  @cmsfiles = Dir[root + '/data/*'].map do |path|
    File.basename(path)
  end

  erb :index
end

# View a document's page
get '/:filename' do
  file_path = root + "/data/" + params[:filename]

  if File.file?(file_path)
    load_file_content(file_path)    
  else
    redirect not_found
  end
end

# Go to the page for editing
get '/:filename/edit' do
  @filename = params[:filename]
  @content = File.read(root + '/data/' + @filename)

  erb :edit_document
end

# Update a file
post '/:filename' do
  file_path = root + '/data/' + params[:filename]
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
