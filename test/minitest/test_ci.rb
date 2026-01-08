require "minitest/autorun"
require "minitest/ci_plugin"

require 'tempfile'
require 'stringio'
require 'nokogiri'

class MockTestSuite < Minitest::Test
  def test_raise_error
    raise 'raise an error'
  end

  def test_fail_assertion
    flunk 'fail assertion'
  end

  def test_skip_assertion
    skip 'skip assertion'
  end

  def test_pass
    pass
  end

  def test_invalid_characters_in_message
    raise Object.new.inspect
  end

  def test_invalid_error_name
    raise Class.new(Exception)
  end

  def test_escaping_failure_message
    flunk "failed: doesn't like single or \"double\" quotes or symbols such as <"
  end
end

describe "spec/with::'punctuation'" do
  it "passes" do
    pass
  end
end

describe "spec/with::\"doublequotes\"" do
  it 'will "pass"' do
    pass
  end
end

describe 'spec/with::long_file_name' * 100 do
  it 'will not throw filename too long errors' do
    pass
  end
end

# better way?
$ci_io = StringIO.new
Minitest::Ci.clean = false

# setup test files
reporter = Minitest::Ci.new $ci_io
reporter.start
Minitest.__run reporter, {}
reporter.report

Minitest::Runnable.reset

class TestMinitest; end

class TestMinitest::TestCiPlugin < Minitest::Test
  def output
    $ci_io
  end

  def setup
    @timestamp = Time.now

    file = "test/reports/TEST-MockTestSuite.xml"
    @file = File.read file
    @doc = Nokogiri.parse @file
    @doc = @doc.at_xpath('/testsuite')
  end

  def test_testsuite
    assert_equal "1", @doc['skipped']
    assert_equal "2", @doc['failures']
    assert_equal "3", @doc['errors']
    assert_equal "3", @doc['assertions']
    assert_equal "7", @doc['tests']
    assert_equal "MockTestSuite", @doc['name']
  end

  def test_testsuite_sets_timestamp
    parsed_time = Time.parse(@doc['timestamp'])
    assert parsed_time.between?(@timestamp-5, @timestamp+5)
  end

  def test_testsuite_timestamp_format
    iso_8061_format = %r{\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}}
    assert_match iso_8061_format, @doc['timestamp']
  end

  def test_testcase_count
    assert_equal 7, @doc.children.count {|c| Nokogiri::XML::Element === c}
    @doc.children.each do |c|
      next unless Nokogiri::XML::Element === c
      assert_equal 'testcase', c.name
    end
  end

  def test_testcase_passed
    passed = @doc.at_xpath('/testsuite/testcase[@name="test_pass"]')
    assert_equal 0, passed.children.count {|c| Nokogiri::XML::Element === c}
    assert_equal '1', passed['assertions']
  end

  def test_testcase_skipped
    skipped = @doc.at_xpath('/testsuite/testcase[@name="test_skip_assertion"]')
    assert_equal 'skip assertion', skipped.at_xpath('skipped')['message']
    assert_equal '0', skipped['assertions']
  end

  def test_testcase_failures
    failure = @doc.at_xpath('/testsuite/testcase[@name="test_fail_assertion"]')
    assert_equal 'fail assertion', failure.at_xpath('failure')['message']
    assert_equal '1', failure['assertions']
  end

  def test_testcase_errors
    error = @doc.at_xpath('/testsuite/testcase[@name="test_raise_error"]')
    assert_equal 'raise an error', error.at_xpath('error')['message']
    assert_equal '0', error['assertions']
  end

  def test_testcase_error_with_invalid_chars
    error = @doc.at_xpath('/testsuite/testcase[@name="test_invalid_characters_in_message"]')
    assert_match( /^#<Object/, error.at_xpath('error')['message'] )
    assert_equal '0', error['assertions']
  end

  def test_testcase_error_with_invalid_name
    error = @doc.at_xpath('/testsuite/testcase[@name="test_invalid_error_name"]')
    assert_match( /^#<Class/, error.at_xpath('error')['message'] )
    assert_equal '0', error['assertions']
  end

  def test_testcase_error_with_bad_chars
    error = @doc.at_xpath('/testsuite/testcase[@name="test_escaping_failure_message"]')
    msg = "failed: doesn't like single or \"double\" quotes or symbols such as <"
    assert_equal msg, error.at_xpath('failure')['message']
    assert_equal '1', error['assertions']
  end

  def test_output
    output.rewind
    expected = "\n[Minitest::CI] Generating test report in JUnit XML format...\n"

    assert_equal expected, output.read
  end

  def test_filtering_backtraces
    error = @doc.at_xpath('/testsuite/testcase[@name="test_raise_error"]')
    refute_match( /lib\/minitest/, error.inner_text )
  end

  def test_suitename_with_single_quotes
    file = File.read "#{Minitest::Ci.report_dir}/TEST-spec_with_punctuation_.xml"
    suite = Nokogiri.parse(file).at_xpath('/testsuite')
    assert_equal "spec/with::'punctuation'", suite['name']
  end

  def test_suitename_with_double_quotes
    file = File.read "#{Minitest::Ci.report_dir}/TEST-spec_with_doublequotes_.xml"
    doc = Nokogiri.parse(file)
    suite = doc.at_xpath('/testsuite')
    testcase = doc.at_xpath('/testsuite/testcase')

    assert_equal 'spec/with::"doublequotes"', suite['name']
    assert_equal 'test_0001_will "pass"', testcase['name']
  end
end

class TestMinitest::TestCiLoading < Minitest::Test
  def output
    @output ||= Tempfile.new("output")
  end

  def test_with_ci_required_explicitly
    test_file = File.expand_path("../../ci_loading_examples/with_ci_required_explicitly.rb", __FILE__)
    system "ruby", test_file, "--no-ci-clean", out: output.path
    assert_includes output.read, "[Minitest::CI] Generating test report in JUnit XML format..."
  end

  def test_with_ci_required_implicitly
    test_file = File.expand_path("../../ci_loading_examples/with_ci_required_implicitly.rb", __FILE__)
    system "ruby", test_file, "--no-ci-clean", out: output.path
    assert_includes output.read, "[Minitest::CI] Generating test report in JUnit XML format..."
  end

  def test_without_ci_required
    test_file = File.expand_path("../../ci_loading_examples/without_ci_required.rb", __FILE__)
    system "ruby", test_file, "--no-ci-clean", out: output.path
    refute_includes output.read, "[Minitest::CI] Generating test report in JUnit XML format..."
  end

  def test_without_ci_required_with_ci_report_option
    test_file = File.expand_path("../../ci_loading_examples/without_ci_required.rb", __FILE__)
    system "ruby", test_file, "--no-ci-clean", "--ci-report", out: output.path
    assert_includes output.read, "[Minitest::CI] Generating test report in JUnit XML format..."
  end
end
