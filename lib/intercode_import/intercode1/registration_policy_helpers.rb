# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module RegistrationPolicyHelpers
      UNLIMITED_POLICY = {
        buckets: [
          { key: 'unlimited', name: 'Signups', description: 'Signups for this event',
            slots_limited: false, anything: false }
        ]
      }.freeze

      BUCKET_DESCRIPTIONS = {
        'Male'    => 'Male characters',
        'Female'  => 'Female characters',
        'Neutral' => 'Characters that are not strictly defined as male or female'
      }.freeze

      def unlimited_registration_policy
        UNLIMITED_POLICY
      end

      def registration_policy_from_row(row)
        buckets = %w[Male Female Neutral].map { |g| bucket_for_gender(row, g) }

        if buckets[0][:total_slots] == 0 && buckets[1][:total_slots] == 0
          buckets = [buckets[2]]
        elsif buckets[2][:total_slots] == 0
          buckets = [buckets[0], buckets[1]]
        end

        if buckets.size == 1 && buckets.first[:key] == 'flex'
          buckets = [buckets.first.merge(key: 'signups', name: 'Signups',
                                         description: 'Signups for this event', anything: false)]
        end

        { buckets: buckets }
      end

      def empty_registration_policy
        { buckets: [] }
      end

      private

      def bucket_for_gender(row, gender)
        key = gender == 'Neutral' ? 'flex' : gender.downcase
        {
          key: key,
          name: gender == 'Neutral' ? 'Flex' : "#{gender} role",
          description: BUCKET_DESCRIPTIONS[gender],
          slots_limited: true,
          anything: key == 'flex',
          total_slots: row[:"MaxPlayers#{gender}"].to_i,
          minimum_slots: row[:"MinPlayers#{gender}"].to_i,
          preferred_slots: row[:"PrefPlayers#{gender}"].to_i
        }
      end
    end
  end
end
