# frozen_string_literal: true

module IntercodeImport
  module Eventlite
    module Tables
      class Pages < Eventlite::Table
        def initialize(connection, event_id, layout_name_by_id)
          super(connection)
          @event_id = event_id
          @layout_name_by_id = layout_name_by_id
        end

        def dataset
          connection[:pages].where(
            Sequel.lit('(parent_type = ? AND parent_id = ?) OR parent_type IS NULL', 'Event', @event_id)
          )
        end

        def export!
          logger.info "Exporting Pages for event #{@event_id}"
          results = []

          dataset.each do |row|
            record = {
              name: row[:name],
              slug: row[:slug],
              content: row[:content] || ''
            }

            layout_name = @layout_name_by_id[row[:cms_layout_id]]
            record[:cms_layout_name] = layout_name if layout_name

            results << record
          end

          results
        end
      end
    end
  end
end
