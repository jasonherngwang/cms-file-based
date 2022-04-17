ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
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

  def create_document(name, content="")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.md"
    create_document "about.txt"
    
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    
    # Search entire HTML string for file names.
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "about.txt"
  end
  
  def test_view_text_document
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    get "/about.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"
  end
    
  def test_view_markdown_document
    create_document "about.md", "# Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_document_not_found
    get "/a.txt"
    
    assert_equal 302, last_response.status
    
    # Follow the redirect.
    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "a.txt does not exist."
    
    # Check that error goes away after reload.
    get "/"
    refute_includes last_response.body, "a.txt does not exist."
  end

  def test_editing_document
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    get "/about.txt/edit"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "button type=\"submit\""
  end

  def test_updating_document
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    post "/about.txt", content: "New content"
    
    assert_equal 302, last_response.status

    get last_response["Location"]
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt has been updated."

    # Check that the changes persisted.
    get "/about.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "New content"
  end
end
