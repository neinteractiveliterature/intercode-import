# frozen_string_literal: true

module IntercodeImport
  module Procon
    module Tables
      class ConventionStaffAttendances < Procon::Table
        include UserHelpers

        ALL_CONVENTION_PERMISSIONS = %w[
          access_admin_notes con_com override_event_tickets read_event_proposals
          read_inactive_events read_limited_prerelease_schedule read_orders
          read_pending_event_proposals read_prerelease_schedule read_reports
          read_schedule_with_counts read_signup_details read_tickets
          read_user_con_profiles read_user_con_profile_email read_user_con_profile_personal_info
          read_user_con_profiles_mailing_list read_team_members_mailing_list
          update_event_proposals update_event_team_members update_events update_rooms update_runs
        ].freeze

        def initialize(connection, convention_id_map, person_id_map, profile_accumulator)
          super(connection)
          @convention_id_map = convention_id_map
          @person_id_map = person_id_map
          @profile_accumulator = profile_accumulator
        end

        def table_name = :attendances

        def dataset
          super.where(event_id: @convention_id_map.keys, is_staff: true)
        end

        # Returns a hash of convention_id => [staff_position_hashes]
        def export!
          logger.info 'Exporting ConventionStaffAttendances'
          by_convention = Hash.new { |h, k| h[k] = {} }
          has_named_positions = connection[:staff_positions].where(id: dataset.map(:staff_position_id)).any?

          dataset.each do |row|
            convention_id = row[:event_id]
            email = email_for_person_id(row[:person_id], convention_id, @person_id_map, @profile_accumulator)
            next unless email

            pos_name, pos_email = resolve_staff_position(row, has_named_positions)
            pos = by_convention[convention_id][pos_name] ||= {
              name: pos_name,
              email: pos_email,
              visible: !!pos_email || has_named_positions,
              permissions: ALL_CONVENTION_PERMISSIONS,
              user_emails: []
            }
            pos[:user_emails] |= [email]
          end

          by_convention.transform_values(&:values)
        end

        private

        def resolve_staff_position(row, has_named_positions)
          if row[:staff_position_id]
            sp_row = connection[:staff_positions].where(id: row[:staff_position_id]).first
            [sp_row[:name], sp_row[:email].presence]
          else
            ['Convention staff', nil]
          end
        end
      end
    end
  end
end
