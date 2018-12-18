# cms_test.rb

ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'

require_relative '../cms'
require 'fileutils'

# require 'pry'

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

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response["Content-Type"]
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_viewing_markdown_document
    content = content_from_main_system_file('about.md')
    create_document 'about.md', content

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes(last_response.body, 'Ruby is...')
    assert_includes(last_response.body, 'simplicity and productivity.')
  end

  def test_history_page
    content = content_from_main_system_file('history.txt')
    create_document 'history.txt', content

    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes(last_response.body, 'History')
    assert_includes(last_response.body, 'Ruby 1.4 released.')
  end

  def test_changes_page
    content = content_from_main_system_file('changes.txt')
    create_document 'changes.txt', content

    get '/changes.txt'

    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes(last_response.body, 'Changes')
    assert_includes(last_response.body, '2013 - Ruby 2.0 released.')
  end

  def test_edit_get_route
    create_document 'changes.txt'

    get '/changes.txt/edit'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<textarea'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_new_document_get_route
    get '/new_document'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_creating_new_document
    post '/create_document', doc_name: 'leisure.txt'

    assert_equal 302, last_response.status

    get last_response["location"]

    assert_includes last_response.body, 'leisure.txt was created.'
    
    get '/'
    assert_includes last_response.body, "leisure.txt"
  end

  def test_create_new_document_without_filename
    post "/create_document", doc_name: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_deleting_a_document
    content = content_from_main_system_file('history.txt')
    create_document 'history.txt', content

    post '/history.txt/delete'

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "history.txt was deleted"

    get "/"
    refute_includes last_response.body, "history.txt"
  end

  def test_sign_in_page
    get '/user/sign_in'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signing_in
    post '/user/sign_in', username: "admin", password: "secret"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, 'Welcome!'
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/user/sign_in", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    post "/user/sign_in", username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"

    post "/user/sign_out"
    get last_response["Location"]

    assert_includes last_response.body, "You have been signed out."
    assert_includes last_response.body, "Sign In"
  end

  def test_not_found
    get '/notta_file.txt'
    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'notta_file.txt does not exist'

    get '/'
    refute_includes last_response.body, 'notta_file.txt does not exist'
  end
end
