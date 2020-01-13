$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'dotenv/load'
require 'memsource'
require 'minitest/autorun'
require 'vcr'

Dotenv.require_keys('TEST_EMAIL', 'TEST_PASSWORD')

VCR.configure do |c|
  c.hook_into :webmock
  c.cassette_library_dir = 'test/cassettes'
  c.default_cassette_options = {
    match_requests_on: %i[method host path]
  }

  %w[
    TEST_EMAIL
    TEST_PASSWORD
  ].each do |key|
    c.filter_sensitive_data("<#{key}>") { ENV[key] }
  end
end

class Minitest::Test
  alias assert_not_nil refute_nil
end
