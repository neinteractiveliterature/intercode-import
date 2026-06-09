# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Signup < Intercode1::Table
        STATE_MAP = {
          'Confirmed' => 'confirmed', 'Waitlisted' => 'waitlisted', 'Withdrawn' => 'withdrawn'
        }.freeze

        def initialize(connection, run_id_map, user_con_profile_id_map, registration_policy_by_event_id)
          super(connection)
          @run_id_map = run_id_map
          @user_con_profile_id_map = user_con_profile_id_map
          @registration_policy_by_event_id = registration_policy_by_event_id
          @signup_counts = Hash.new { |h, k| h[k] = Hash.new(0) }
        end

        def dataset
          super.order(:TimeStamp)
        end

        private

        def build_record(row)
          run_ref  = @run_id_map[row[:RunId]]
          email    = @user_con_profile_id_map[row[:UserId]]

          unless run_ref
            logger.info "Signup #{row[:SignupId]} references run #{row[:RunId]}, which does not exist"
            return
          end
          unless email
            logger.info "Signup #{row[:SignupId]} references user #{row[:UserId]}, which does not exist"
            return
          end

          counted = row[:Counted] == 'Y'
          state   = STATE_MAP[row[:State]]
          policy  = @registration_policy_by_event_id[run_ref[:event_id]]

          bucket_key = counted ? resolve_bucket_key(row, run_ref, policy) : nil
          requested_bucket_key = counted ? row[:Gender]&.downcase : nil

          return if counted && state == 'confirmed' && bucket_key.nil?

          {
            event_id: run_ref[:event_id],
            run_index: run_ref[:run_index],
            user_email: email,
            bucket_key: bucket_key,
            requested_bucket_key: requested_bucket_key,
            state: state,
            counted: counted
          }.compact
        end

        def row_id(row) = row[:SignupId]

        def resolve_bucket_key(row, run_ref, policy)
          return nil unless row[:Counted] == 'Y' && row[:State] == 'Confirmed'
          return nil unless policy

          gender_key = row[:Gender]&.downcase
          anything_key = policy[:buckets].size == 1 ? policy[:buckets].first[:key] : 'flex'
          bucket_key = slot_available?(run_ref, gender_key, policy) ? gender_key : anything_key
          slot_available?(run_ref, bucket_key, policy) ? bucket_key : nil
        end

        def slot_available?(run_ref, bucket_key, policy)
          return false unless bucket_key
          bucket = policy[:buckets].find { |b| b[:key] == bucket_key }
          return false unless bucket
          return true unless bucket[:slots_limited]

          used = @signup_counts[run_ref[:event_id]][bucket_key]
          total = bucket[:total_slots].to_i
          if used < total
            @signup_counts[run_ref[:event_id]][bucket_key] += 1
            true
          else
            false
          end
        end
      end
    end
  end
end
