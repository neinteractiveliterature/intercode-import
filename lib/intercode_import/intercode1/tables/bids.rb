# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Bids < Intercode1::Table
        include RegistrationPolicyHelpers

        YN_TO_BOOL = ->(v) { v == 'Y' }

        BID_STATUS_MAP = {
          'Pending'      => 'proposed',
          'Under Review' => 'reviewing',
          'Accepted'     => 'accepted',
          'Rejected'     => 'rejected',
          'Dropped'      => 'withdrawn'
        }.freeze

        BID_ATTRIBUTES = {
          Title:                  { form_field: 'title' },
          Author:                 { form_field: 'authors' },
          Organization:           { form_field: 'organization' },
          Homepage:               { form_field: 'url' },
          GameEMail:              { form_field: 'email' },
          Hours:                  { form_field: 'length_seconds', convert: ->(v) { v.to_i * 3600 } },
          Description:            { form_field: 'description', markdownify: true },
          ShortBlurb:             { form_field: 'short_blurb', markdownify: true },
          PlayerCommunications:   { form_field: 'player_communications' },
          Genre:                  { form_field: 'genre' },
          OngoingCampaign:        { form_field: 'ongoing_campaign', convert: YN_TO_BOOL },
          RunBefore:              { form_field: 'run_before' },
          GameSystem:             { form_field: 'game_system' },
          CombatResolution:       { form_field: 'combat_resolution' },
          Premise:                { form_field: 'other_committee_info' },
          SetupTeardown:          { form_field: 'setup_teardown' },
          GMs:                    { form_field: 'gms' },
          OtherGames:             { form_field: 'other_games' },
          Offensive:              { form_field: 'offensive' },
          PhysicalRestrictions:   { form_field: 'physical_restrictions' },
          AgeAppropriate:         { form_field: 'age_appropriate' },
          CanPlayConcurrently:    { form_field: 'can_play_concurrently', convert: YN_TO_BOOL },
          MultipleRuns:           { form_field: 'multiple_runs', convert: YN_TO_BOOL },
          SchedulingConstraints:  { form_field: 'scheduling_constraints' },
          SpaceRequirements:      { form_field: 'space_requirements' },
          ShortSentence:          { form_field: 'short_sentence' },
          ShamelessPlugs:         { form_field: 'shameless_plugs' },
          GMGameAdvertising:      { form_field: 'gm_game_advertising' },
          GMConAdvertising:       { form_field: 'gm_con_advertising' },
          SendFlyers:             { form_field: 'send_flyers', convert: YN_TO_BOOL },
          IsSmallGameContestEntry: { form_field: 'is_small_games_contest_entry', convert: YN_TO_BOOL }
        }.freeze

        def initialize(connection, event_id_map, user_con_profile_id_map)
          super(connection)
          @event_id_map = event_id_map
          @user_con_profile_id_map = user_con_profile_id_map
          @markdownifier = IntercodeImport::Markdownifier.new(logger)
        end

        private

        def build_record(row)
          owner_email = @user_con_profile_id_map[row[:UserId]]
          return unless owner_email

          {
            owner_email: owner_email,
            event_category_name: 'larp',
            event_id: @event_id_map[row[:EventId]],
            status: BID_STATUS_MAP[row[:Status]],
            form_response_attributes: form_response_attributes(row)
          }.compact
        end

        def row_id(row) = row[:BidId]

        def form_response_attributes(row)
          attrs = BID_ATTRIBUTES.each_with_object({}) do |(bid_attr, opts), h|
            next unless row.key?(bid_attr)
            value = row[bid_attr]
            next if value.nil?
            value = opts[:convert].call(value) if opts[:convert]
            value = @markdownifier.markdownify(value) if opts[:markdownify]
            h[opts[:form_field]] = value
          end
          attrs.merge('registration_policy' => registration_policy_from_row(row))
        end
      end
    end
  end
end
