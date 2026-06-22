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

          all_items = dataset.all
          top_level = all_items.select { |r| r[:navigation_section_id].nil? }
          children_by_section = all_items.group_by { |r| r[:navigation_section_id] }
          children_by_section.delete(nil)

          sections = []
          top_level.each do |item|
            if item[:page_id].nil?
              links = (children_by_section[item[:id]] || []).filter_map do |child|
                page_name = page_name_by_id[child[:page_id]]
                next unless page_name
                { title: child[:title], page_name: page_name }
              end
              sections << { title: item[:title], links: links } unless links.empty?
            else
              page_name = page_name_by_id[item[:page_id]]
              next unless page_name
              sections << { title: item[:title], links: [{ title: item[:title], page_name: page_name }] }
            end
          end

          sections
        end
      end
    end
  end
end
