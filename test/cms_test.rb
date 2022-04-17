ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    # Search entire HTML string for file names.
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "about.txt"
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "history.txt"
  end

  def test_view_text_document
    get "/about.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"
  end
    
  def test_document_not_found
    get "/a.txt"
    assert_equal 302, last_response.status
    
    # Follow the redirect
    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "a.txt does not exist."
    
    # Check that error goes away after reload
    get "/"
    refute_includes last_response.body, "a.txt does not exist."
  end
  
  def test_render_markdown
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
    # assert_includes invokes String#include?
    assert_includes last_response.body, "Yukihiro &quot;Matz&quot; Matsumoto"
    assert last_response.body.include? "Yukihiro &quot;Matz&quot; Matsumoto"
    assert_match "Yukihiro &quot;Matz&quot; Matsumoto", last_response.body
  end
end
