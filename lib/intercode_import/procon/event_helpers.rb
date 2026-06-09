# frozen_string_literal: true

module IntercodeImport
  module Procon
    module EventHelpers
      def force_timezone(time, timezone_name)
        zone = ActiveSupport::TimeZone[timezone_name]
        zone.parse(time.strftime('%Y-%m-%d %H:%M:%S'))
      end

      def event_registration_open?(row)
        connection[:registration_rules]
          .where(type: 'ClosedEventRule', policy_id: row[:registration_policy_id]).count == 0
      end

      def event_has_counted_attendances?(row)
        connection[:attendances].where(event_id: row[:id], counts: true).any?
      end

      def can_play_concurrently?(row)
        connection[:registration_rules]
          .where(policy_id: row[:registration_policy_id], type: 'ExclusiveEventRule').count == 0
      end

      def age_restrictions(row)
        rule = connection[:registration_rules]
                 .where(policy_id: row[:registration_policy_id], type: 'AgeRestrictionRule').first
        return nil unless rule
        "Must be at least #{rule[:min_age]} years old"
      end
    end
  end
end
