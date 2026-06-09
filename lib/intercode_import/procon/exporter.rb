# frozen_string_literal: true

require 'sequel'

module IntercodeImport
  module Procon
    # ProCon exports produce one JSON file per convention matched by the domain regex.
    class Exporter
      def initialize(procon_db_url, illyan_db_url, convention_domain_regex, organization_name)
        logger.info 'Connecting to ProCon database'
        @procon_connection = Sequel.connect(procon_db_url)
        logger.info 'Connecting to Illyan database'
        @illyan_connection = Sequel.connect(illyan_db_url)
        @convention_domain_regex = Regexp.new(convention_domain_regex)
        @organization_name = organization_name
      end

      # Returns an array of export hashes, one per matched convention.
      def export
        people_table = Tables::People.new(@procon_connection, @illyan_connection)
        users = people_table.export!
        person_id_map = people_table.id_map

        conventions_table = Tables::Conventions.new(
          @procon_connection, @convention_domain_regex, @organization_name
        )
        convention_data_list = conventions_table.export!
        convention_id_map = conventions_table.id_map
        convention_data_by_id = convention_data_list.each_with_object({}) do |c, h|
          h[c[:id].to_i] = c
        end

        profile_accumulator = Hash.new { |h, k| h[k] = [] }

        proposed_events_table = Tables::ProposedEvents.new(
          @procon_connection, convention_id_map, person_id_map, profile_accumulator
        )
        proposed_events_list = proposed_events_table.export!
        proposed_event_id_map = proposed_events_table.id_map

        events_table = Tables::Events.new(
          @procon_connection, convention_data_by_id, proposed_event_id_map,
          person_id_map, profile_accumulator
        )
        all_events, all_runs = events_table.export!
        registration_policy_by_event_id = all_events.each_with_object({}) { |e, h| h[e[:id]] = e[:registration_policy] }
        run_id_map = build_run_id_map(all_runs)

        attendances_table = Tables::Attendances.new(
          @procon_connection, convention_data_by_id, person_id_map, run_id_map,
          profile_accumulator, registration_policy_by_event_id
        )
        all_signups, all_team_members = attendances_table.export!

        staff_by_convention = Tables::ConventionStaffAttendances.new(
          @procon_connection, convention_id_map, person_id_map, profile_accumulator
        ).export!

        convention_data_list.map do |con_data|
          con_id_str = con_data[:id]
          con_id_int = con_id_str.to_i

          con_events    = all_events.select { |e| event_belongs_to?(e, con_id_str, con_data) }
          con_event_ids = Set.new(con_events.map { |e| e[:id] })
          con_runs      = all_runs.select { |r| con_event_ids.include?(r[:event_id]) }
          con_signups   = all_signups.select { |s| con_event_ids.include?(s[:event_id]) }
          con_team_members = all_team_members.select { |t| con_event_ids.include?(t[:event_id]) }
          con_proposals = proposed_events_list.select { |p| p[:convention_id] == con_id_str }
          con_profiles  = profile_accumulator[con_id_int]

          # Expand convention times to fit runs
          starts_at, ends_at = expand_times(con_data, con_runs)

          convention = con_data.except(:id, :organization_name).merge(
            starts_at: starts_at,
            ends_at: ends_at,
            staff_positions: staff_by_convention[con_id_int] || [],
            rooms: con_runs.flat_map { |r| r[:room_names] }.uniq.map { |n| { name: n } }
          )

          {
            version: '1',
            source_system: 'procon',
            organization_name: @organization_name,
            cms_content_set: con_data[:cms_content_set],
            convention: convention,
            users: users_for_convention(users, con_profiles),
            user_con_profiles: con_profiles,
            events: con_events.map { |e| e.except(:event_proposal_id) },
            event_proposals: con_proposals.map { |p| p.except(:convention_id) },
            runs: con_runs,
            signups: con_signups,
            team_members: con_team_members,
            tickets: [],
            store_items: [],
            store_orders: []
          }
        end
      end

      private

      def logger
        Procon.logger
      end

      def build_run_id_map(all_runs)
        indexes = Hash.new(-1)
        all_runs.each_with_object({}) do |run, map|
          indexes[run[:event_id]] += 1
        end
      end

      def event_belongs_to?(event, con_id_str, con_data)
        # For single_event conventions, the event id == convention id
        return true if event[:id] == con_id_str
        # For multi-event conventions, check parent via ProCon events table
        @procon_connection[:events].where(id: event[:id].to_i, parent_id: con_id_str.to_i).any?
      end

      def users_for_convention(all_users, profiles)
        emails = Set.new(profiles.map { |p| p[:user_email] })
        all_users.select { |u| emails.include?(u[:email]) }
      end

      def expand_times(con_data, runs)
        starts_at = con_data[:starts_at]
        ends_at   = con_data[:ends_at]
        return [starts_at, ends_at] if runs.empty?

        run_starts = runs.map { |r| Time.parse(r[:starts_at]) }
        min_start  = [Time.parse(starts_at), *run_starts].min
        # Assume 4-hour runs as a default length when we don't have end times
        max_end    = [Time.parse(ends_at), *(run_starts.map { |t| t + 4.hours })].max

        [min_start.iso8601, max_end.iso8601]
      end
    end
  end
end
