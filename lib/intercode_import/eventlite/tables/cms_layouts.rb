# frozen_string_literal: true

module IntercodeImport
  module Eventlite
    module Tables
      class CmsLayouts < Eventlite::Table
        def initialize(connection, event_id)
          super(connection)
          @event_id = event_id
        end

        def dataset
          connection[:cms_layouts].where(
            Sequel.lit('(parent_type = ? AND parent_id = ?) OR parent_type IS NULL', 'Event', @event_id)
          )
        end

        def export!
          logger.info "Exporting CmsLayouts for event #{@event_id}"
          results = []

          dataset.each do |row|
            id_map[row[:id]] = row[:name]
            results << { name: row[:name], content: row[:content] || '' }
          end

          results
        end
      end
    end
  end
end
