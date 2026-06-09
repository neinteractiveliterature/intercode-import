# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class PreConRuns < Intercode1::Table
        include DateHelpers

        def initialize(connection, con_starts_at, con_timezone_name, pre_con_event_id_map, room_id_map)
          super(connection)
          @con_starts_at = con_starts_at
          @con_timezone  = ActiveSupport::TimeZone[con_timezone_name]
          @pre_con_event_id_map = pre_con_event_id_map
          @room_id_map = room_id_map
          @run_indexes = Hash.new(-1)
        end

        def export!
          logger.info 'Exporting PreConRuns'
          results = []
          dataset.each do |row|
            record = build_record(row)
            results << record if record
          end
          results
        end

        private

        def build_record(row)
          event_id = @pre_con_event_id_map[row[:PreConEventId]]
          return unless event_id

          @run_indexes[event_id] += 1

          {
            event_id: event_id,
            starts_at: start_time(row).iso8601,
            title_suffix: row[:TitleSuffix].presence,
            schedule_note: row[:ScheduleNote].presence,
            room_names: (row[:Rooms] || '').split(',').map(&:strip).map { |n| @room_id_map[n] }.compact
          }.compact
        end

        def row_id(row) = row[:PreConRunId]

        def start_time(row)
          start_of_convention_day(@con_timezone, @con_starts_at, row[:Day]) + row[:StartHour].to_i.hours
        end
      end
    end
  end
end
