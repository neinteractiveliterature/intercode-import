# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Runs < Intercode1::Table
        include DateHelpers

        def initialize(connection, con_starts_at, con_timezone_name, event_id_map, room_id_map)
          super(connection)
          @con_starts_at = con_starts_at
          @con_timezone  = ActiveSupport::TimeZone[con_timezone_name]
          @event_id_map  = event_id_map
          @room_id_map   = room_id_map
          @run_indexes   = Hash.new(-1)
        end

        def dataset
          if connection.table_exists?(:RunsRooms)
            super
              .left_join(:RunsRooms, RunId: :RunId)
              .select_all(:Runs)
              .select_append(Sequel.lit('GROUP_CONCAT(RunsRooms.RoomId)').as(:RoomIds))
              .group_by(:RunId)
          else
            super
          end
        end

        private

        def build_record(row)
          event_id = @event_id_map[row[:EventId]]
          return unless event_id

          @run_indexes[event_id] += 1
          id_map[row[:RunId]] = { event_id: event_id, run_index: @run_indexes[event_id] }

          {
            event_id: event_id,
            starts_at: start_time(row).iso8601,
            title_suffix: row[:TitleSuffix].presence,
            schedule_note: row[:ScheduleNote].presence,
            room_names: room_names(row)
          }.compact
        end

        def row_id(row) = row[:RunId]

        def export!
          logger.info 'Exporting Runs'
          results = []
          dataset.each do |row|
            record = build_record(row)
            results << record if record
          end
          results
        end

        def start_time(row)
          start_hour = row[:StartHour].to_i
          start_of_convention_day(@con_timezone, @con_starts_at, row[:Day]) + start_hour.hours
        end

        def room_names(row)
          if connection.table_exists?(:RunsRooms)
            (row[:RoomIds] || '').split(',').map(&:to_i).map { |id| @room_id_map[id] }.compact
          else
            (row[:Rooms] || row[:Venue] || '').split(',').map(&:strip).map { |name| @room_id_map[name] }.compact
          end
        end
      end
    end
  end
end
