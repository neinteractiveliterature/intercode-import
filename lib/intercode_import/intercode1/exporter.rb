# frozen_string_literal: true

require 'bcrypt'
require 'parallel'
require 'sequel'

module IntercodeImport
  module Intercode1
    class Exporter
      STAFF_POSITION_NAMES = {
        'ADVERTISING'          => 'Advertising',
        'ATTENDEE_COORDINATOR' => 'Attendee Coordinator',
        'BID_CHAIR'            => 'Game Proposals Chair',
        'CON_CHAIR'            => 'Con Chair',
        'CON_SUITE'            => 'Hospitality Coordinator',
        'GM_COORDINATOR'       => 'GM Coordinator',
        'HOTEL_LIAISON'        => 'Hotel Liaison',
        'IRON_GM'              => 'Iron GM Coordinator',
        'OPS'                  => 'Operations Coordinator',
        'OPS2'                 => 'Operations Coordinator',
        'OUTREACH'             => 'Outreach Coordinator',
        'REGISTRAR'            => 'Registrar',
        'SAFETY_COORDINATOR'   => 'Safety Coordinator',
        'STAFF_COORDINATOR'    => 'Volunteer Coordinator',
        'THURSDAY'             => 'Panel Coordinator',
        'TREASURER'            => 'Treasurer',
        'VENDOR_LIAISON'       => 'Vendor Coordinator'
      }.freeze

      def initialize(constants_file, con_domain: nil)
        @constants_file = constants_file
        @config = Configuration.new(constants_file)
        @connection = Sequel.connect(@config.var(:database_url))
        @con_domain = con_domain || @config.var(:con_name)&.downcase&.gsub(/\s+/, '-') + '.intercode.test'
        @password_hashes = {}
      end

      def build_password_hashes
        unless @connection.schema(:Users).any? { |col| col.first == :HashedPassword }
          logger.warn 'No HashedPassword column; users will need to reset passwords'
          return
        end

        logger.info 'Hashing legacy MD5 passwords with BCrypt'
        rows = @connection[:Users].select(:UserId, :HashedPassword).to_a
        hashes = Parallel.map(rows, in_processes: Parallel.processor_count) do |row|
          [row[:UserId], BCrypt::Password.create(row[:HashedPassword])]
        end
        @connection = Sequel.connect(@config.var(:database_url))
        @password_hashes = Hash[hashes]
      end

      def export
        con_table = Tables::Con.new(@connection, {
          con_name: @config.var(:con_name),
          con_domain: @con_domain,
          constants_file: @constants_file,
          maximum_tickets: @config.var(:maximum_tickets),
          timezone_name: 'US/Eastern',
          friday_date: @config.var(:friday_date),
          thursday_enabled: @config.var(:thursday_enabled)
        })
        convention = con_table.export_convention

        events_table = Tables::Events.new(@connection)
        events = events_table.export!
        event_id_map = events_table.id_map
        registration_policy_by_event_id = events.each_with_object({}) do |e, h|
          h[e[:id]] = e[:registration_policy]
        end

        users_table = Tables::Users.new(@connection, event_id_map, @password_hashes)
        users, user_con_profiles, tickets = users_table.export!
        user_con_profile_id_map = users_table.user_con_profile_id_map

        bios_table = Tables::Bios.new(@connection, user_con_profile_id_map)
        bio_updates = bios_table.export!
        apply_bio_updates(user_con_profiles, bio_updates)

        away_table = Tables::Away.new(@connection, user_con_profile_id_map)
        away_emails = away_table.export!
        apply_away_updates(user_con_profiles, away_emails)

        bids_table = Tables::Bids.new(@connection, event_id_map, user_con_profile_id_map)
        event_proposals = bids_table.export!

        rooms_table = Tables::Rooms.new(@connection)
        rooms = rooms_table.export!
        room_id_map = rooms_table.id_map
        convention[:rooms] = rooms.map { |r| { name: r[:name] } }

        starts_at = Time.parse(convention[:starts_at])
        runs_table = Tables::Runs.new(
          @connection, starts_at, convention[:timezone_name], event_id_map, room_id_map
        )
        runs = runs_table.export!
        run_id_map = runs_table.id_map

        gms_table = Tables::GMs.new(@connection, event_id_map, user_con_profile_id_map)
        team_members = gms_table.export!

        signup_table = Tables::Signup.new(
          @connection, run_id_map, user_con_profile_id_map, registration_policy_by_event_id
        )
        signups = signup_table.export!

        staff_positions = build_staff_positions(
          users_table.staff_position_accumulator, @config.var(:staff_positions)
        )
        convention[:staff_positions] = staff_positions

        ticket_types = build_ticket_types(users_table.ticket_types_used, @config.var(:price_schedule))
        convention[:ticket_types] = ticket_types

        store_items, store_orders = export_store(user_con_profile_id_map)

        pre_con_events, pre_con_runs = export_pre_con(starts_at, convention[:timezone_name], room_id_map)

        {
          version: '1',
          source_system: 'intercode1',
          cms_content_set: 'standard',
          organization_name: nil,
          convention: convention,
          users: users,
          user_con_profiles: user_con_profiles,
          events: events + pre_con_events,
          event_proposals: event_proposals,
          runs: runs + pre_con_runs,
          signups: signups,
          team_members: team_members,
          tickets: tickets,
          store_items: store_items,
          store_orders: store_orders
        }
      end

      private

      def logger
        Intercode1.logger
      end

      def apply_bio_updates(user_con_profiles, bio_updates)
        user_con_profiles.each do |profile|
          update = bio_updates[profile[:user_email]]
          next unless update
          profile.merge!(update)
        end
      end

      def apply_away_updates(user_con_profiles, away_emails)
        away_set = Set.new(away_emails)
        user_con_profiles.each do |profile|
          profile[:receive_whos_free_emails] = false if away_set.include?(profile[:user_email])
        end
      end

      def build_staff_positions(accumulator, php_staff_positions)
        positions = accumulator.map do |key, data|
          {
            name: key,
            permissions: data[:permissions],
            user_emails: data[:user_emails],
            visible: data[:visible] || false
          }
        end

        (php_staff_positions || {}).each do |key, data|
          name = STAFF_POSITION_NAMES[key] || key
          existing = positions.find { |p| p[:name] == name }
          if existing
            existing[:email] = data['email'].presence
          else
            positions << { name: name, email: data['email'].presence, user_emails: [] }
          end
        end

        positions.map(&:compact)
      end

      def build_ticket_types(ticket_types_used, price_schedule)
        ticket_types_used.map do |status|
          Tables::Users::REGISTRATION_STATUS_TICKET_TYPES[status]
        end
      end

      def export_store(user_con_profile_id_map)
        unless @connection.table_exists?('StoreItems')
          logger.info 'No StoreItems table; skipping store export'
          return [[], []]
        end

        items_table = Tables::StoreItems.new(@connection)
        store_items = items_table.export!
        item_name_map = items_table.id_map.transform_values { |id| store_items.find { |i| i[:id] == id }&.dig(:name) }

        orders_table = Tables::StoreOrders.new(@connection, user_con_profile_id_map)
        store_orders = orders_table.export!
        order_id_map = orders_table.id_map

        entries_table = Tables::StoreOrderEntries.new(@connection, order_id_map, item_name_map)
        entries_by_order = entries_table.export!

        store_orders.each do |order|
          order[:entries] = entries_by_order[order[:id]] || []
          order.delete(:id)
        end

        [store_items.map { |i| i.except(:id) }, store_orders]
      end

      def export_pre_con(con_starts_at, con_timezone_name, room_id_map)
        return [[], []] unless @connection.table_exists?('PreConEvents')

        events_table = Tables::PreConEvents.new(@connection)
        events = events_table.export!
        event_id_map = events_table.id_map

        runs_table = Tables::PreConRuns.new(
          @connection, con_starts_at, con_timezone_name, event_id_map, room_id_map
        )
        runs = runs_table.export!

        [events, runs]
      end
    end
  end
end
