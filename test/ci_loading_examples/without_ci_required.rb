require 'bundler/inline'

gemfile do
  gem 'minitest'
  gem 'minitest-ci', path: File.expand_path("../../..", __FILE__), require: false
end

require 'minitest/autorun'
Minitest.load :ci if Minitest.respond_to? :load # MT6: plugins are now opt-in

class WithoutCiRequiredTest < Minitest::Test
  def test_one
    assert true
  end
end
