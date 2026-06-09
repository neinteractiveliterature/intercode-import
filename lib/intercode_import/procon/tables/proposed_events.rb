# frozen_string_literal: true

module IntercodeImport
  module Procon
    module Tables
      class ProposedEvents < Procon::Table
        include EventHelpers
        include UserHelpers

        def initialize(connection, convention_id_map, person_id_map, profile_accumulator)
          super(connection)
          @convention_id_map = convention_id_map
          @person_id_map = person_id_map
          @profile_accumulator = profile_accumulator
          @markdownifier = IntercodeImport::Markdownifier.new(logger)
        end

        def table_name = :events

        def dataset
          super.where(type: 'ProposedEvent', parent_id: @convention_id_map.keys)
        end

        private

        def build_record(row)
          convention_id = @convention_id_map.keys.find { |id| id.to_s == row[:parent_id].to_s }
          return unless convention_id

          owner_email = email_for_person_id(
            row[:proposer_id], convention_id, @person_id_map, @profile_accumulator
          )
          return unless owner_email

          accepted = connection[:events].where(proposed_event_id: row[:id]).any?

          {
            owner_email: owner_email,
            event_category_name: 'Larp',
            convention_id: convention_id.to_s,
            status: accepted ? 'accepted' : 'reviewing',
            form_response_attributes: {
              title: row[:fullname],
              short_name: row[:shortname],
              short_blurb: row[:blurb] || row[:description],
              description: row[:description] || row[:blurb],
              can_play_concurrently: can_play_concurrently?(row),
              age_restrictions: age_restrictions(row),
              proposed_timing: row[:proposed_timing],
              proposal_comments: row[:proposal_comments],
              proposed_location: row[:proposed_location],
              proposed_capacity_limits: row[:proposed_capacity_limits]
            }.compact
          }
        end
      end
    end
  end
end
