# frozen_string_literal: true

module IntercodeImport
  module Procon
    module Tables
      class Events < Procon::Table
        include EventHelpers
        include UserHelpers

        BUCKET_ATTRS_BY_GENDER = {
          'male'    => { key: 'female', name: 'Female role', description: 'Female characters',
                         slots_limited: true, anything: false },
          'female'  => { key: 'male',   name: 'Male role',   description: 'Male characters',
                         slots_limited: true, anything: false },
          'neutral' => { key: 'flex',   name: 'Flex',
                         description: 'Characters not strictly defined as male or female',
                         slots_limited: true, anything: true }
        }.freeze

        def initialize(connection, convention_id_map, proposed_event_id_map, person_id_map, profile_accumulator)
          super(connection)
          @convention_id_map = convention_id_map
          @proposed_event_id_map = proposed_event_id_map
          @person_id_map = person_id_map
          @profile_accumulator = profile_accumulator
          @markdownifier = IntercodeImport::Markdownifier.new(logger)
          @run_indexes = Hash.new(-1)
        end

        def dataset
          not_proposal = (Sequel.~(Sequel[{ type: 'ProposedEvent' }]) | Sequel[{ type: nil }])
          convention_ids = @convention_id_map.keys
          single_event_ids = @convention_id_map.select { |_, v| v[:site_mode] == 'single_event' }.keys
          multi_event_ids  = @convention_id_map.select { |_, v| v[:site_mode] == 'convention' }.keys

          super
            .where(not_proposal & Sequel[{ parent_id: multi_event_ids }])
            .or(not_proposal & Sequel[{ id: single_event_ids }])
        end

        def export!
          logger.info 'Exporting ProCon Events'
          events = []
          runs = []
          dataset.each do |row|
            event, run = build_event_and_run(row)
            next unless event
            events << event
            runs << run if run
          end
          [events, runs]
        end

        private

        def build_event_and_run(row)
          convention_id = row[:parent_id] || row[:id]
          convention_data = @convention_id_map[convention_id]
          return unless convention_data

          event_category = row[:type] == 'LimitedCapacityEvent' ? 'Larp' : 'Con services'
          proposal_id = @proposed_event_id_map[row[:proposed_event_id]]

          event = {
            id: row[:id].to_s,
            title: row[:fullname],
            event_category_name: event_category,
            status: 'active',
            con_mail_destination: 'gms',
            event_proposal_id: proposal_id,
            registration_policy: registration_policy(row),
            form_response_attributes: form_response_attributes(row).compact
          }.compact

          @run_indexes[row[:id]] += 1
          run = {
            event_id: row[:id].to_s,
            starts_at: force_timezone(row[:start], convention_data[:timezone_name]).iso8601,
            room_names: location_names_for_event(row[:id])
          }

          [event, run]
        end

        def location_names_for_event(event_id)
          connection[:locations]
            .join(:event_locations, location_id: :id)
            .where(event_id: event_id)
            .map(:name)
        end

        def form_response_attributes(row)
          {
            title: row[:fullname],
            short_name: row[:shortname],
            short_blurb: row[:blurb] || row[:description],
            length_seconds: row[:end].to_i - row[:start].to_i,
            description: row[:description] || row[:blurb],
            can_play_concurrently: can_play_concurrently?(row),
            age_restrictions: age_restrictions(row)
          }
        end

        def registration_policy(row)
          if row[:type] != 'LimitedCapacityEvent'
            if event_registration_open?(row) || event_has_counted_attendances?(row)
              return { buckets: [{ key: 'unlimited', name: 'Signups', slots_limited: false, anything: false }] }
            end
            return { buckets: [] }
          end

          buckets = buckets_for_event(row)
          buckets = postprocess_buckets(buckets)
          { buckets: buckets }
        end

        def postprocess_buckets(buckets)
          return buckets unless buckets.select { |b| b[:total_slots].to_i > 0 }.map { |b| b[:key] } == ['flex']

          flex = buckets.find { |b| b[:key] == 'flex' }
          [flex.merge(key: 'signups', name: 'Signups', description: 'Signups for this event',
                      anything: false, slots_limited: true)]
        end

        def buckets_for_event(row)
          slot_buckets = connection[:attendee_slots].where(event_id: row[:id]).map do |s|
            BUCKET_ATTRS_BY_GENDER[s[:gender]].merge(
              minimum_slots: s[:min], preferred_slots: s[:preferred], total_slots: s[:max]
            )
          end

          reg_buckets = connection[:registration_buckets].where(event_id: row[:id]).to_a
          reg_buckets_mapped = reg_buckets.map.with_index do |rb, i|
            gender = reg_buckets.size == 1 ? 'neutral' : { 0 => 'male', 1 => 'female', 2 => 'neutral' }[i] || 'neutral'
            gender = { 1 => 'male', 2 => 'female', 3 => 'neutral' }[rb[:position]] || gender
            BUCKET_ATTRS_BY_GENDER[gender].merge(
              minimum_slots: rb[:min], preferred_slots: rb[:preferred], total_slots: rb[:max]
            )
          end

          slot_buckets + reg_buckets_mapped
        end
      end
    end
  end
end
