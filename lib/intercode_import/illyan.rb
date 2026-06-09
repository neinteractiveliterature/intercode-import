# frozen_string_literal: true

require_relative 'illyan/password_migration'
require_relative 'illyan/table'
require_relative 'illyan/tables/people'
require_relative 'illyan/exporter'

module IntercodeImport
  module Illyan
    def self.logger
      IntercodeImport::Logger.instance
    end
  end
end
