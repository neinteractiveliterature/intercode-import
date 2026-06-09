# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'stringio'
require 'intercode_import'
require 'intercode_import/intercode1'
require 'intercode_import/illyan'

SILENT_LOGGER = ::Logger.new(StringIO.new)
