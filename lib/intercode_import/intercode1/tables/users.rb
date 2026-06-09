# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Users < Intercode1::Table
        CONTACT_FIELD_MAP = {
          first_name: :FirstName, last_name: :LastName, nickname: :Nickname,
          city: :City, state: :State, zipcode: :Zipcode, country: :Country,
          day_phone: :DayPhone, evening_phone: :EvePhone,
          best_call_time: :BestTime, gender: :Gender, preferred_contact: :PreferredContact,
          birth_date: :BirthYear
        }.freeze

        PREFERRED_CONTACT_MAP = {
          'EMail' => 'email', 'DayPhone' => 'day_phone', 'EvePhone' => 'evening_phone'
        }.freeze

        PERMISSIONS_MAP = {
          BidChair: %w[access_admin_notes read_event_proposals read_pending_event_proposals update_event_proposals],
          BidCom: %w[read_event_proposals],
          ConCom: %w[read_orders read_prerelease_schedule read_reports read_schedule_with_counts
                     read_signup_details read_tickets read_user_con_profiles
                     read_user_con_profile_email read_user_con_profile_personal_info],
          GMLiaison: %w[access_admin_notes override_event_tickets read_event_proposals
                        read_inactive_events read_limited_prerelease_schedule read_prerelease_schedule
                        read_schedule_with_counts update_event_proposals update_event_team_members
                        update_events update_rooms update_runs],
          MailToAll: %w[read_user_con_profiles_mailing_list read_team_members_mailing_list],
          MailToAttendees: %w[read_user_con_profiles_mailing_list],
          MailToGMs: %w[read_team_members_mailing_list],
          Outreach: %w[read_signup_details],
          Scheduling: %w[access_admin_notes override_event_tickets read_event_proposals
                         read_inactive_events read_limited_prerelease_schedule
                         read_pending_event_proposals read_prerelease_schedule
                         read_schedule_with_counts update_event_proposals update_events
                         update_rooms update_runs]
        }.freeze

        ALL_CONVENTION_PERMISSIONS = %w[
          access_admin_notes con_com override_event_tickets read_event_proposals
          read_inactive_events read_limited_prerelease_schedule read_orders
          read_pending_event_proposals read_prerelease_schedule read_reports
          read_schedule_with_counts read_signup_details read_tickets
          read_user_con_profiles read_user_con_profile_email read_user_con_profile_personal_info
          read_user_con_profiles_mailing_list read_team_members_mailing_list
          update_event_proposals update_event_team_members update_events update_rooms update_runs
        ].freeze

        REGISTRATION_STATUS_TICKET_TYPES = {
          'Paid'      => { name: 'paid', description: 'Paid badge' },
          'Comp'      => { name: 'event_comp', description: 'Comp badge for event',
                           maximum_event_provided_tickets: 2 },
          'Marketing' => { name: 'marketing_comp', description: 'Marketing comp badge' },
          'Vendor'    => { name: 'vendor', description: 'Vendor badge',
                           counts_towards_convention_maximum: false, allows_event_signups: false },
          'Rollover'  => { name: 'rollover', description: 'Rollover badge' }
        }.freeze

        attr_reader :user_con_profile_id_map, :staff_position_accumulator, :ticket_types_used

        def initialize(connection, event_id_map, legacy_password_md5s)
          super(connection)
          @event_id_map = event_id_map
          @legacy_password_md5s = legacy_password_md5s
          @user_con_profile_id_map = {}
          @staff_position_accumulator = Hash.new { |h, k| h[k] = { permissions: [], user_emails: [] } }
          @ticket_types_used = Set.new
        end

        def export!
          logger.info 'Exporting Users'
          users = []
          user_con_profiles = []
          tickets = []
          seen_emails = {}

          dataset.each do |row|
            email = row[:EMail].to_s.downcase.strip
            next if email.blank?

            password_hash = @legacy_password_md5s[row[:UserId]]

            unless seen_emails[email]
              seen_emails[email] = true
              users << build_user(row, email, password_hash)
            end

            profile = build_user_con_profile(row, email)
            id_map[row[:UserId]] = email
            @user_con_profile_id_map[row[:UserId]] = email
            user_con_profiles << profile

            accumulate_permissions(row, email)

            ticket = build_ticket(row, email)
            tickets << ticket if ticket
          end

          [users, user_con_profiles, tickets]
        end

        private

        def build_user(row, email, password_hash)
          {
            email: email,
            first_name: row[:FirstName].presence || email,
            last_name: row[:LastName].presence || '',
            password_hash: password_hash,
            password_hash_type: password_hash ? 'bcrypt_wrapped_md5' : nil
          }.compact
        end

        def build_user_con_profile(row, email)
          address = [row[:Address1], row[:Address2]].map(&:presence).compact.join("\n").presence
          birth_year = row[:BirthYear]

          {
            user_email: email,
            first_name: row[:FirstName].presence,
            last_name: row[:LastName].presence,
            nickname: row[:Nickname].presence,
            day_phone: row[:DayPhone].presence,
            evening_phone: row[:EvePhone].presence,
            best_call_time: row[:BestTime].presence,
            preferred_contact: PREFERRED_CONTACT_MAP[row[:PreferredContact]],
            address: address,
            city: row[:City].presence,
            state: row[:State].presence,
            zipcode: row[:Zipcode].presence,
            country: row[:Country].presence,
            gender: row[:Gender].presence&.downcase,
            birth_date: (birth_year && birth_year > 0 ? Date.new(birth_year, 1, 1).iso8601 : nil),
            additional_info: { how_heard: row[:HowHeard].presence }
          }.compact
        end

        def accumulate_permissions(row, email)
          PERMISSIONS_MAP.each do |priv, permissions|
            next unless row[priv]
            pos_name = priv.to_s
            @staff_position_accumulator[pos_name][:permissions] |= permissions
            @staff_position_accumulator[pos_name][:user_emails] |= [email]
            @staff_position_accumulator[pos_name][:visible] = false
          end

          if row[:Staff]
            @staff_position_accumulator['Staff'][:permissions] |= ALL_CONVENTION_PERMISSIONS
            @staff_position_accumulator['Staff'][:user_emails] |= [email]
            @staff_position_accumulator['Staff'][:visible] = true
          end
        end

        def build_ticket(row, email)
          status = row[:CanSignup].to_s
          return nil unless REGISTRATION_STATUS_TICKET_TYPES.key?(status)

          @ticket_types_used << status
          ticket = { user_email: email, ticket_type_name: status }

          if row[:CompEventId].present? && @event_id_map[row[:CompEventId]]
            ticket[:provided_by_event_id] = @event_id_map[row[:CompEventId]]
          end

          if row[:PaymentAmount].to_i > 0
            ticket[:payment_amount] = { fractional: row[:PaymentAmount].to_i * 100, currency_code: 'USD' }
          end

          ticket[:payment_note] = row[:PaymentNote].presence
          ticket.compact
        end
      end
    end
  end
end
