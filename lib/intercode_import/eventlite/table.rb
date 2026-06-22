# frozen_string_literal: true

module IntercodeImport
  module Eventlite
    class Table < IntercodeImport::Table
      def table_name
        self.class.name.demodulize.underscore.to_sym
      end

      private

      def row_id(row) = row[:id]

      def logger
        IntercodeImport::Eventlite.logger
      end
    end
  end
end
