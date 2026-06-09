# frozen_string_literal: true

module IntercodeImport
  module Illyan
    class Table < IntercodeImport::Table
      private

      def logger
        IntercodeImport::Illyan.logger
      end
    end
  end
end
