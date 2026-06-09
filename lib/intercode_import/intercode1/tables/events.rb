# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Events < Intercode1::Table
        include RegistrationPolicyHelpers

        INTERCON_Q_PRECON_PREFIXES = %w[DISCUSSION PANEL RANT WORKSHOP PRESENTATION MEETUP].freeze

        def initialize(connection)
          super
          @markdownifier = IntercodeImport::Markdownifier.new(logger)
          @seen_titles = Hash.new(0)
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
          {
            id: row[:EventId].to_s,
            title: unique_title(event_title(row)),
            event_category_name: event_category(row),
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
            registration_policy: registration_policy(row, event_category(row))
          }.compact
        end

        def row_id(row) = row[:EventId]

        def event_category(row)
          return 'volunteer_event' if row[:IsOps] == 'Y' || row[:IsConSuite] == 'Y'
          if row[:SpecialEvent] == 1
            return 'panel' if parse_precon_prefix(row)
            return 'filler'
          end
          category_for_game_type(row[:GameType])
        end

        def category_for_game_type(game_type)
          case game_type
          when 'Board Game'  then 'board_game'
          when 'Panel'       then 'panel'
          when 'Tabletop RPG' then 'tabletop_rpg'
          when 'Other'       then nil
          else 'larp'
          end
        end

        def event_status(row)
          return 'active' if row[:SpecialEvent]
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

        def registration_policy(row, category)
          case category
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
