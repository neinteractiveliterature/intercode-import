# frozen_string_literal: true

module IntercodeImport
  module Procon
    module Tables
      class Attendances < Procon::Table
        include UserHelpers

        def initialize(connection, convention_id_map, person_id_map, run_id_map,
                       profile_accumulator, registration_policy_by_event_id)
          super(connection)
          @convention_id_map = convention_id_map
          @person_id_map = person_id_map
          @run_id_map = run_id_map
          @profile_accumulator = profile_accumulator
          @registration_policy_by_event_id = registration_policy_by_event_id
        end

        def dataset
          super.where(event_id: @run_id_map.keys)
        end

        def export!
          logger.info 'Exporting Attendances (signups + team members)'
          signups = []
          team_members = []

          dataset.each do |row|
            run_ref = @run_id_map[row[:event_id]]
            next unless run_ref

            convention_id = find_convention_id(run_ref[:event_id])
            next unless convention_id

            email = email_for_person_id(row[:person_id], convention_id, @person_id_map, @profile_accumulator)
            next unless email

            policy = @registration_policy_by_event_id[run_ref[:event_id]]
            target_key = find_target_bucket_key(row, policy)
            actual_key = find_actual_bucket_key(row, run_ref, target_key, policy)
            state = signup_state(row)

            signups << {
              event_id: run_ref[:event_id],
              run_index: run_ref[:run_index],
              user_email: email,
              requested_bucket_key: (target_key == 'flex' ? nil : target_key),
              bucket_key: actual_key,
              state: state,
              counted: row[:counts]
            }.compact

            if row[:is_staff]
              team_members << {
                event_id: run_ref[:event_id],
                user_email: email,
                display: true,
                show_email: false,
                receive_con_email: true,
                receive_signup_email: 'no'
              }
            end
          end

          [signups, team_members]
        end

        private

        def find_convention_id(event_id)
          @convention_id_map.each do |con_id, _|
            return con_id if connection[:events].where(id: event_id, parent_id: con_id).any?
            return con_id if con_id.to_s == event_id.to_s
          end
          nil
        end

        def find_target_bucket_key(row, policy)
          return nil unless policy
          return policy[:buckets].first&.dig(:key) if policy[:buckets].size == 1
          row[:gender] == 'neutral' ? 'flex' : row[:gender]
        end

        def find_actual_bucket_key(row, run_ref, target_key, policy)
          return nil unless signup_state(row) == 'confirmed' && row[:counts] && target_key && policy
          target_bucket = policy[:buckets].find { |b| b[:key] == target_key }
          return target_key unless target_bucket
          flex_bucket = policy[:buckets].find { |b| b[:key] == 'flex' }
          flex_bucket ? 'flex' : target_key
        end

        def signup_state(row)
          return 'withdrawn'  if row[:deleted_at]
          return 'waitlisted' if row[:is_waitlist]
          'confirmed'
        end
      end
    end
  end
end
