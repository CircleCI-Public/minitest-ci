require 'minitest/autorun'
require 'minitest/ci'
require 'stringio'

TestOptionsDescription = 'report with this name should be transformed in sha1'

class TestPass < Minitest::Test
  def test_pass
    pass
  end
end

describe TestOptionsDescription do
  it 'passes' do
    pass
  end
end

# Setup tests reporter using sha1
$ci_io = StringIO.new
Minitest::Ci.clean = false
reporter = Minitest::Ci.new $ci_io, { :report_name => :sha1 }
reporter.start
Minitest.seed = 42
if Minitest.respond_to? :__run then
  Minitest.__run reporter, {}
else
  Minitest.run_all_suites reporter, {} # WTF is this for?
end
reporter.report

class TestOptions < Minitest::Test
  def test_filename_is_sha1_digest
    sha1 = Digest::SHA1.hexdigest(TestOptionsDescription)
    assert File.exist? "test/reports/TEST-#{sha1}.xml"
  end
end

describe 'report with this name should be reversed' do
  it 'passes' do
    pass
  end
end

class TestPassAgain < Minitest::Test
  def test_pass
    pass
  end
end

# Resetup test reporter using Proc
$ci_io = StringIO.new
Minitest::Ci.clean = false
reporter = Minitest::Ci.new $ci_io, {
  :report_name => Proc.new do |name|
    "TEST-#{CGI.escape(name.to_s.gsub(/\W+/, '_').reverse)[0, 246]}.xml"
  end
}
reporter.start
if Minitest.respond_to? :__run then
  Minitest.__run reporter, {}
else
  Minitest.seed = 42
  Minitest.run_all_suites reporter, {} # WTF is this for?
end
reporter.report

class TestOptionsProc < Minitest::Test
  def test_filename_is_from_given_proc
    assert File.exist? "test/reports/TEST-desrever_eb_dluohs_eman_siht_htiw_troper.xml"
  end
end
