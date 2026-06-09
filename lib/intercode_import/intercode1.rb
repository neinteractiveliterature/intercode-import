# frozen_string_literal: true

require_relative 'intercode1/configuration'
require_relative 'intercode1/date_helpers'
require_relative 'intercode1/php'
require_relative 'intercode1/html_converter'
require_relative 'intercode1/cms_content'
require_relative 'intercode1/registration_policy_helpers'
require_relative 'intercode1/table'
require_relative 'intercode1/tables'
require_relative 'intercode1/exporter'

module IntercodeImport
  module Intercode1
    def self.logger
      IntercodeImport::Logger.instance
    end
  end
end
