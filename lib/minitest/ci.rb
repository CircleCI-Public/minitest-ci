require 'minitest/ci_plugin'
Minitest.load :ci if Minitest.respond_to? :load # MT6: plugins are now opt-in
Minitest::Ci.report!
