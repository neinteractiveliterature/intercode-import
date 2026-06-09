# frozen_string_literal: true

module IntercodeImport
  module Procon
    class Table < IntercodeImport::Table
      def table_name
        self.class.name.demodulize.downcase.to_sym
      end

      private

      def row_id(row) = row[:id]

      def logger
        IntercodeImport::Procon.logger
      end
    end
  end
end
