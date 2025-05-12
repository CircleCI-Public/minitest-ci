require 'fileutils'
if RUBY_VERSION < '3.5'
  require 'cgi/util'
else
  require 'cgi/escape'
end
require 'time'
require 'digest'

module Minitest
  def self.plugin_ci_options opts, options
    opts.on "--ci-report", "Enable Minitest::Ci Reporting." do |dir|
      Ci.report!
    end

    opts.on "--ci-dir DIR", "Set the CI report dir. Default to #{Ci.report_dir}" do |dir|
      options[:ci_dir] = dir
    end

    opts.on "--[no-]ci-clean", "Clean the CI report dir in between test runs. Default #{Ci.clean}" do |clean|
      options[:ci_clean] = clean
    end

    opts.on "--working-dir DIR", "Set the working dir. Default to #{Ci.working_dir}" do |dir|
      options[:working_dir] = dir
    end

    opts.on "--report-name REPORT_NAME_OPTION", "Set report name option. Default to :test_name" do |report_name_option|
      options[:report_name] = report_name_option
    end
  end

  def self.plugin_ci_init options
    if Ci.report?
      self.reporter << Ci.new(options[:io], options)
    end
  end

  class Ci < Reporter
    class << self
      ##
      # Activates minitest/ci plugin as a Minitest reporter
      def report!
        @report = true
      end

      ##
      # Is minitest/ci activated as a Minitest reporter?
      def report?
        @report ||= false
      end

      ##
      # Change the report directory. (defaults to "test/reports")
      attr_accessor :report_dir

      ##
      # Clean the report_dir between test runs? (defaults to true)
      attr_accessor :clean

      ##
      # Change the working directory. (defaults to `$PWD`)
      attr_accessor :working_dir
    end

    self.report_dir = 'test/reports'
    self.clean      = true
    self.working_dir = Dir.pwd

    attr_accessor :io
    attr_accessor :options
    attr_accessor :results

    def initialize io = $stdout, options = {}
      self.io      = io
      self.options = options
      self.results = Hash.new {|h,k| h[k] = []}
    end

    def passed?
      true # don't care?
    end

    def start # clean
      FileUtils.rm_rf   report_dir if clean?
      FileUtils.mkdir_p report_dir
    end

    def record result
      key = result.respond_to?(:klass) ? result.klass : result.class
      results[key] << result
    end

    ##
    # Generate test report
    def report
      io.puts
      io.puts '[Minitest::CI] Generating test report in JUnit XML format...'

      Dir.chdir report_dir do
        results.each do |name, result|
          File.open(report_name(name), "w") do |f|
            f.puts( generate_results(name, result) )
          end
        end
      end
    end

    private

    def escape o
      CGI.escapeHTML(o.to_s)
    end

    def generate_results name, results
      total_time = assertions = errors = failures = skips = 0
      timestamp = Time.now.iso8601
      results.each do |result|
        total_time += result.time
        assertions += result.assertions

        case result.failure
        when Skip
          skips += 1
        when UnexpectedError
          errors += 1
        when Assertion
          failures += 1
        end
      end

      base = working_dir + '/'
      xml = []

      xml << '<?xml version="1.0" encoding="UTF-8"?>'
      xml << "<testsuite time='%6f' skipped='%d' failures='%d' errors='%d' name=%p assertions='%d' tests='%d' timestamp=%p>" %
        [total_time, skips, failures, errors, escape(name), assertions, results.count, timestamp]

      results.each do |result|
        location = if result.respond_to? :source_location then
                     result.source_location
                   else
                     result.method(result.name).source_location
                   end[0].gsub(base, '')
        xml << "  <testcase time='%6f' file=%p name=%p assertions='%s'>" %
          [result.time, escape(location), escape(result.name), result.assertions]
        if failure = result.failure
          label = failure.result_label.downcase

          if failure.is_a?(UnexpectedError)
            failure = failure.error
          end

          klass = failure.class
          msg   = failure.message
          bt    = Minitest::filter_backtrace failure.backtrace

          xml << "    <%s type='%s' message=%s>%s" %
            [label, escape(klass), escape(msg).inspect.gsub('\n', "&#13;&#10;"), escape(bt.join("\n"))]
          xml << "    </%s>" % label
        end
        xml << "  </testcase>"
      end

      xml << "</testsuite>"

      xml
    end

    def working_dir
      options.fetch(:working_dir, self.class.working_dir)
    end

    def report_dir
      options.fetch(:ci_dir, self.class.report_dir)
    end

    def clean?
      options.fetch(:ci_clean, self.class.clean)
    end

    def report_name(name)
      report_name_opt = options.fetch(:report_name, :test_name)
      return report_name_opt.call(name) if report_name_opt.is_a? Proc
      return sha1_report_name(name) if report_name_opt.to_sym == :sha1
      test_name_report_name(name)
    end

    def sha1_report_name(name)
      "TEST-#{Digest::SHA1.hexdigest(name.to_s)}.xml"
    end

    def test_name_report_name(name)
      "TEST-#{CGI.escape(name.to_s.gsub(/\W+/, '_'))[0, 246]}.xml"
    end
  end
end
