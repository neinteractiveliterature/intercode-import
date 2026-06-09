# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module DateHelpers
      DAY_OFFSETS = { 'Thu' => -1, 'Fri' => 0, 'Sat' => 1, 'Sun' => 2 }.freeze

      def friday_start(timezone, starts_at)
        t = starts_at.in_time_zone(timezone)
        base = t.friday? ? t.beginning_of_day : t.thursday? ? (t.beginning_of_day + 1.day) : nil
        raise "Convention starts_at is neither Thursday nor Friday" unless base
        base
      end

      def start_of_convention_day(timezone, starts_at, short_day_name)
        friday_start(timezone, starts_at) + DAY_OFFSETS.fetch(short_day_name).days
      end
    end
  end
end
