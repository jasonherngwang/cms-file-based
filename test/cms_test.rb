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
    assert_includes last_response.body, "history.txt"
  end

  def test_view_text_document
    get "/about.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"
  end
end
