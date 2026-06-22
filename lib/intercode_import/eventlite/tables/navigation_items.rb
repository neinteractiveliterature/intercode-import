# frozen_string_literal: true

module IntercodeImport
  module Eventlite
    module Tables
      class NavigationItems < Eventlite::Table
        def initialize(connection, event_id)
          super(connection)
          @event_id = event_id
        end

        def dataset
          connection[:navigation_items].where(
            Sequel.lit('(parent_type = ? AND parent_id = ?) OR parent_type IS NULL', 'Event', @event_id)
          ).order(:position)
        end

        def export!
          logger.info "Exporting NavigationItems for event #{@event_id}"

          page_name_by_id = connection[:pages].select(:id, :name, :content).all.each_with_object({}) do |row, h|
            next if eventlite_only_content?(row[:content])
            h[row[:id]] = row[:name]
          end

          links = dataset.filter_map do |row|
            page_name = page_name_by_id[row[:page_id]]
            next unless page_name
            { title: row[:title], page_name: page_name }
          end

          links.empty? ? [] : [{ title: 'Navigation', links: links }]
        end
      end
    end
  end
end
