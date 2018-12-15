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
