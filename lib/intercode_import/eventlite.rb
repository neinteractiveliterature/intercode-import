# frozen_string_literal: true

require_relative 'eventlite/table'
require_relative 'eventlite/tables'
require_relative 'eventlite/exporter'

module IntercodeImport
  module Eventlite
    def self.logger
      IntercodeImport::Logger.instance
    end
  end
end
