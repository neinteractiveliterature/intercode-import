# frozen_string_literal: true

require 'sequel'

module IntercodeImport
  module Illyan
    class Exporter
      def initialize(illyan_db_url, emails)
        logger.info 'Connecting to Illyan database'
        @connection = Sequel.connect(illyan_db_url)
        @emails = emails
      end

      def export
        Tables::People.new(@connection, @emails).export!
      end

      private

      def logger
        Illyan.logger
      end
    end
  end
end
