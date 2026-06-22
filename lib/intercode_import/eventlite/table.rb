# frozen_string_literal: true

module IntercodeImport
  module Eventlite
    class Table < IntercodeImport::Table
      # Liquid tags that exist in Eventlite but not in Intercode's environment.
      EVENTLITE_ONLY_TAGS = %w[ticket_form].freeze

      def table_name
        self.class.name.demodulize.underscore.to_sym
      end

      private

      def row_id(row) = row[:id]

      def logger
        IntercodeImport::Eventlite.logger
      end

      def eventlite_only_content?(content)
        return false unless content&.include?('{%')
        EVENTLITE_ONLY_TAGS.any? { |tag| content.match?(/\{%-?\s*#{tag}[\s%}]/) }
      end
    end
  end
end
