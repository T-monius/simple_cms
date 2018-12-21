# cms_test.rb

ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'
require 'fileutils'

require 'pry'

class SimpleCMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(filepath, name, content = "")
    File.open(File.join(filepath, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin", signed_in: true } }
  end

  def test_index
    create_document data_path, "about.md"
    create_document data_path, "changes.txt"

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_viewing_markdown_document
    content = content_from_main_program_file('about.md')
    create_document data_path, 'about.md', content

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes(last_response.body, 'Ruby is...')
    assert_includes(last_response.body, 'simplicity and productivity.')
  end

  def test_history_page
    content = content_from_main_program_file('history.txt')
    create_document data_path, 'history.txt', content

    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes(last_response.body, 'History')
    assert_includes(last_response.body, 'Ruby 1.4 released.')
  end

  def test_changes_page
    content = content_from_main_program_file('changes.txt')
    create_document data_path, 'changes.txt', content

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes(last_response.body, 'Changes')
    assert_includes(last_response.body, '2013 - Ruby 2.0 released.')
  end

  def test_edit_form
    get "/", {}, admin_session
    create_document data_path, 'changes.txt'

    get '/changes.txt/edit'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_editing_document_signed_out
    create_document data_path, "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    get "/", {}, admin_session
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_updating_document_signed_out
    post "/changes.txt", {content: "new content"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form
    get "/", {}, admin_session
    get '/new_document'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_document_form_signed_out
    get "/new_document"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_creating_new_document
    get "/", {}, admin_session
    post '/create_document', doc_name: 'leisure.txt'

    assert_equal 302, last_response.status
    assert_equal 'leisure.txt was created.', session[:message]
    
    get '/'
    assert_includes last_response.body, "leisure.txt"
  end

  def test_create_new_document_signed_out
    post "/create_document", {filename: "test.txt"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_without_filename
    get "/", {}, admin_session
    post "/create_document", doc_name: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_deleting_a_document
    get "/", {}, admin_session
    content = content_from_main_program_file('history.txt')
    create_document data_path, 'history.txt', content

    post '/history.txt/delete'

    assert_equal 302, last_response.status
    assert_equal "history.txt was deleted.", session[:message]

    get "/"
    assert_includes last_response.body, "history.txt was deleted"
    refute_includes last_response.body, ">history.txt</a>"
    refute_includes last_response.body, %q(href="/history.txt")
  end

  def test_deleting_document_signed_out
    create_document data_path, "test.txt"

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_sign_in_page
    get '/user/sign_in'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signing_in
    create_document config_path, 'users.yml', content_from_main_config_file('users.yml')

    post '/user/sign_in', username: "admin", password: "secret"

    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    create_document config_path, 'users.yml', content_from_main_config_file('users.yml')

    post "/user/sign_in", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/user/sign_out"
    assert_equal 'You have been signed out.', session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def test_not_found
    get '/notta_file.txt'

    assert_equal 302, last_response.status
    assert_equal 'notta_file.txt does not exist.', session[:message]
  end
end
