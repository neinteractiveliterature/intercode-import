# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Events < Intercode1::Table
        include RegistrationPolicyHelpers

        INTERCON_Q_PRECON_PREFIXES = %w[DISCUSSION PANEL RANT WORKSHOP PRESENTATION MEETUP].freeze

        CATEGORY_DEFINITIONS = {
          'larp' => {
            name: 'LARP', team_member_name: 'GM', scheduling_ui: 'regular',
            event_form_title: 'Regular event form', event_proposal_form_title: 'Proposal form'
          },
          'tabletop_rpg' => {
            name: 'Tabletop RPG', team_member_name: 'GM', scheduling_ui: 'regular',
            event_form_title: 'Regular event form', event_proposal_form_title: 'Proposal form'
          },
          'panel' => {
            name: 'Panel', team_member_name: 'Organizer', scheduling_ui: 'single_run',
            event_form_title: 'Filler event form'
          },
          'board_game' => {
            name: 'Board Game', team_member_name: 'Host', scheduling_ui: 'single_run',
            event_form_title: 'Filler event form'
          },
          'filler' => {
            name: 'Filler', team_member_name: 'Organizer', scheduling_ui: 'single_run',
            event_form_title: 'Filler event form'
          },
          'volunteer_event' => {
            name: 'Volunteer Event', team_member_name: 'Coordinator', scheduling_ui: 'single_run',
            event_form_title: 'Volunteer event form'
          }
        }.freeze

        def initialize(connection)
          super
          @markdownifier = IntercodeImport::Markdownifier.new(logger)
          @seen_titles = Hash.new(0)
          @used_category_keys = Set.new
        end

        def used_event_categories
          @used_category_keys.filter_map { |key| CATEGORY_DEFINITIONS[key] }
        end

        def dataset
          super
            .left_outer_join(:Bids, EventId: :EventId)
            .select_all(:Events)
            .select_append(:Status)
            .where(Status: %w[Accepted Dropped])
            .or(SpecialEvent: 1)
        end

        private

        def build_record(row)
          category_key = raw_event_category_key(row)
          category_name = CATEGORY_DEFINITIONS.dig(category_key, :name) || 'Filler'
          @used_category_keys << (category_key || 'filler')

          {
            id: row[:EventId].to_s,
            title: unique_title(event_title(row)),
            event_category_name: category_name,
            status: event_status(row),
            author: row[:Author].presence,
            email: row[:GameEMail].presence,
            organization: row[:Organization].presence,
            url: row[:Homepage].presence,
            length_seconds: row[:Hours].to_i * 3600,
            can_play_concurrently: row[:CanPlayConcurrently] == 'Y',
            con_mail_destination: con_mail_destination(row),
            description: @markdownifier.markdownify(row[:Description]),
            short_blurb: @markdownifier.markdownify(row[:ShortBlurb]),
            participant_communications: @markdownifier.markdownify(row[:PlayerCommunications]),
            registration_policy: registration_policy(row, category_key)
          }.compact
        end

        def row_id(row) = row[:EventId]

        def raw_event_category_key(row)
          return 'volunteer_event' if row[:IsOps] == 'Y' || row[:IsConSuite] == 'Y'
          if row[:SpecialEvent] == 1
            return 'panel' if parse_precon_prefix(row)
            return 'filler'
          end
          category_key_for_game_type(row[:GameType])
        end

        def category_key_for_game_type(game_type)
          case game_type
          when 'Board Game'   then 'board_game'
          when 'Panel'        then 'panel'
          when 'Tabletop RPG' then 'tabletop_rpg'
          when 'Other'        then nil
          else 'larp'
          end
        end

        def event_status(row)
          return 'active' if row[:SpecialEvent] == 1
          row[:Status] == 'Accepted' ? 'active' : 'dropped'
        end

        def con_mail_destination(row)
          case row[:ConMailDest].presence
          when 'GameMail' then 'event_email'
          when 'GMs'      then 'gms'
          when nil        then row[:GameEMail].present? ? 'event_email' : 'gms'
          else raise "Unknown ConMailDest: #{row[:ConMailDest]}"
          end
        end

        def registration_policy(row, category_key)
          case category_key
          when 'larp', 'volunteer_event' then registration_policy_from_row(row)
          else unlimited_registration_policy
          end
        end

        def parse_precon_prefix(row)
          INTERCON_Q_PRECON_PREFIXES.each do |prefix|
            return prefix if row[:Title].to_s =~ /\A#{prefix}\s*[:-]/i
          end
          nil
        end

        def event_title(row)
          return row[:Title] unless row[:SpecialEvent] == 1
          prefix = parse_precon_prefix(row)
          return row[:Title] unless prefix
          row[:Title].to_s.sub(/\A#{prefix}\s*[:-]\s*/i, '')
        end

        def unique_title(title)
          @seen_titles[title] += 1
          count = @seen_titles[title]
          count == 1 ? title : "#{title} [#{count}]"
        end
      end
    end
  end
end
