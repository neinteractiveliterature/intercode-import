# frozen_string_literal: true

require_relative 'procon/event_helpers'
require_relative 'procon/user_helpers'
require_relative 'procon/table'
require_relative 'procon/tables'
require_relative 'procon/exporter'

module IntercodeImport
  module Procon
    def self.logger
      IntercodeImport::Logger.instance
    end
  end
end
