# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Rooms < Intercode1::Table
        def initialize(connection)
          super
        end

        def export!
          if connection.table_exists?(table_name)
            super
          else
            logger.info 'Exporting legacy rooms from Runs columns'
            legacy_room_names.each do |name|
              id_map[name] = name
            end
            legacy_room_names.map { |name| { name: name } }
          end
        end

        private

        def build_record(row)
          { id: row[:RoomId].to_s, name: row[:RoomName] }
        end

        def row_id(row) = row[:RoomId]

        def legacy_room_names
          rooms_col = connection.schema(:Runs).find { |col| col.first == :Rooms }
          if rooms_col
            rooms_col.second[:db_type].scan(/'([^']+)'/).map(&:first)
          else
            connection[:Runs].pluck(:Venue)
              .flat_map { |v| v.to_s.split(',').map(&:strip) }
              .uniq
              .reject(&:blank?)
          end
        end
      end
    end
  end
end
