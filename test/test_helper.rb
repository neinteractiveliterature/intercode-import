# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'minitest/reporters'
require 'stringio'
require 'intercode_import'
require 'intercode_import/intercode1'
require 'intercode_import/illyan'
require 'intercode_import/eventlite'
require_relative 'support/db_test_helper'
require_relative 'support/eventlite_db_test_helper'

if ENV['CI'].present?
  Minitest::Reporters.use!(
    [
      Minitest::Reporters::SpecReporter.new,
      Minitest::Reporters::HtmlReporter.new(output_filename: 'minitest-report.html'),
      Minitest::Reporters::JUnitReporter.new
    ],
    ENV,
    Minitest.backtrace_filter
  )
else
  Minitest::Reporters.use!(Minitest::Reporters::ProgressReporter.new, ENV, Minitest.backtrace_filter)
end

SILENT_LOGGER = ::Logger.new(StringIO.new)
