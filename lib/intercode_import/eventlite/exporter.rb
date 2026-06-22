# frozen_string_literal: true

require 'sequel'
require 'set'

module IntercodeImport
  module Eventlite
    class Exporter
      def initialize(db_url, domain_suffix: 'example.com', timezone: 'UTC', file_base_url: nil)
        logger.info 'Connecting to Eventlite database'
        @connection = Sequel.connect(db_url)
        @domain_suffix = domain_suffix
        @timezone = timezone
        @file_base_url = file_base_url
      end

      def export
        site_settings = @connection[:site_settings].first

        users_table = Tables::Users.new(@connection)
        all_users = users_table.export!
        user_email_by_id = users_table.id_map

        @connection[:events].order(:id).map do |event_row|
          export_event(event_row, site_settings, all_users, user_email_by_id)
        end
      end

      private

      def export_event(event_row, site_settings, all_users, user_email_by_id)
        event_id   = event_row[:id]
        event_name = event_row[:name]
        event_slug = event_row[:slug].presence || event_name.to_s.downcase.gsub(/\s+/, '-')

        layouts_table     = Tables::CmsLayouts.new(@connection, event_id)
        cms_layouts       = layouts_table.export!
        layout_name_by_id = layouts_table.id_map

        default_layout_content = nil
        if event_row[:default_cms_layout_id]
          default_row = @connection[:cms_layouts].where(id: event_row[:default_cms_layout_id]).first
          default_layout_content = default_row&.fetch(:content, nil)
        end

        ticket_type_rows = @connection[:ticket_types].where(event_id: event_id).order(:id).all
        ticket_type_name_by_id = ticket_type_rows.each_with_object({}) { |r, h| h[r[:id]] = r[:name] }

        ticket_types = ticket_type_rows.map do |tt|
          {
            name: tt[:name],
            allows_event_signups: true,
            counts_towards_convention_maximum: true
          }
        end

        tickets_table = Tables::Tickets.new(@connection, event_id, ticket_type_name_by_id, user_email_by_id)
        tickets = tickets_table.export!

        ticket_emails     = Set.new(tickets.map { |t| t[:user_email] })
        event_users       = all_users.select { |u| ticket_emails.include?(u[:email]) }
        user_con_profiles = build_profiles(event_id, user_email_by_id)

        store_items  = build_store_items(ticket_type_rows)
        store_orders = build_store_orders(event_id, ticket_type_name_by_id, user_email_by_id, ticket_type_rows)

        cms_pages     = Tables::Pages.new(@connection, event_id, layout_name_by_id).export!
        cms_files     = Tables::CmsFiles.new(@connection, event_id, @file_base_url).export!
        cms_nav_items = Tables::NavigationItems.new(@connection, event_id).export!

        convention = {
          name:             site_settings&.fetch(:site_title, nil).presence || event_name,
          domain:           "#{event_slug}.#{@domain_suffix}",
          timezone_name:    @timezone,
          site_mode:        'single_event',
          ticket_mode:      'ticket_per_event',
          ticket_types:     ticket_types,
          event_categories: [default_event_category],
          rooms:            [],
          staff_positions:  admin_staff_positions(event_users)
        }

        if event_row[:start_time]
          convention[:starts_at] = event_row[:start_time].iso8601
          if event_row[:length_seconds]
            convention[:ends_at] = (event_row[:start_time] + event_row[:length_seconds]).iso8601
          end
        end

        convention[:default_layout_content] = default_layout_content if default_layout_content

        event_record = {
          id:                   event_id.to_s,
          title:                event_name,
          event_category_name:  'Event',
          status:               'active',
          registration_policy:  build_registration_policy(ticket_type_rows)
        }
        event_record[:length_seconds] = event_row[:length_seconds] if event_row[:length_seconds]

        run = { event_id: event_id.to_s, room_names: [] }
        run[:starts_at] = event_row[:start_time].iso8601 if event_row[:start_time]

        signups = build_signups(event_id.to_s, tickets, ticket_type_rows)

        {
          version:              '1',
          source_system:        'eventlite',
          cms_content_set:      'single_event',
          convention:           convention,
          users:                event_users,
          user_con_profiles:    user_con_profiles,
          events:               [event_record],
          runs:                 [run],
          signups:              signups,
          team_members:         [],
          tickets:              tickets,
          store_items:          store_items,
          store_orders:         store_orders,
          cms_layouts:          cms_layouts,
          cms_pages:            cms_pages,
          cms_files:            cms_files,
          cms_navigation_items: cms_nav_items
        }
      end

      def build_registration_policy(ticket_type_rows)
        if ticket_type_rows.size <= 1
          return {
            buckets: [{ key: 'attendees', name: 'Attendees', slots_limited: false, anything: false }],
            prevent_no_preference_signups: false
          }
        end

        buckets = ticket_type_rows.map do |tt|
          bucket = { key: bucket_key_for(tt[:name]), name: tt[:name], anything: false }
          if tt[:number_available]
            bucket.merge!(slots_limited: true, total_slots: tt[:number_available],
                          minimum_slots: 0, preferred_slots: tt[:number_available])
          else
            bucket[:slots_limited] = false
          end
          bucket
        end
        { buckets: buckets, prevent_no_preference_signups: false }
      end

      def build_signups(event_id_str, tickets, ticket_type_rows)
        if ticket_type_rows.size <= 1
          return tickets.map do |ticket|
            { event_id: event_id_str, run_index: 0, user_email: ticket[:user_email],
              state: 'confirmed', bucket_key: 'attendees', counted: true }
          end
        end

        slots_by_name = ticket_type_rows.each_with_object({}) { |r, h| h[r[:name]] = r[:number_available] || 0 }

        tickets.group_by { |t| t[:user_email] }.map do |user_email, user_tickets|
          best = user_tickets.max_by { |t| slots_by_name[t[:ticket_type_name]] || 0 }
          { event_id: event_id_str, run_index: 0, user_email: user_email,
            state: 'confirmed', bucket_key: bucket_key_for(best[:ticket_type_name]), counted: true }
        end
      end

      def bucket_key_for(name)
        name.to_s.downcase.gsub(/\s+/, '_').gsub(/[^\w]/, '')
      end

      def build_store_items(ticket_type_rows)
        ticket_type_rows.map do |tt|
          item = {
            name:                      tt[:name],
            available:                 true,
            provides_ticket_type_name: tt[:name]
          }
          item[:price] = { fractional: tt[:price_cents], currency_code: 'USD' } if tt[:price_cents]
          item
        end
      end

      def build_store_orders(event_id, ticket_type_name_by_id, user_email_by_id, ticket_type_rows)
        price_by_ticket_type_id = ticket_type_rows.each_with_object({}) { |r, h| h[r[:id]] = r[:price_cents] }

        ticket_rows = @connection[:tickets]
          .join(:ticket_types, id: :ticket_type_id)
          .where(Sequel[:ticket_types][:event_id] => event_id)
          .select_all(:tickets)
          .all

        ticket_rows.filter_map do |row|
          user_email =
            if row[:user_id]
              user_email_by_id[row[:user_id]]
            else
              row[:email].to_s.downcase.strip.presence
            end
          next unless user_email

          ticket_type_name = ticket_type_name_by_id[row[:ticket_type_id]]
          next unless ticket_type_name

          entry = { store_item_name: ticket_type_name, quantity: 1 }

          list_price_cents = price_by_ticket_type_id[row[:ticket_type_id]]
          entry[:price_per_item] = { fractional: list_price_cents, currency_code: 'USD' } if list_price_cents

          order = {
            user_email: user_email,
            status:     row[:canceled_at] ? 'cancelled' : 'paid',
            entries:    [entry]
          }

          if row[:payment_amount_cents]
            order[:payment_amount] = { fractional: row[:payment_amount_cents], currency_code: 'USD' }
          end

          order
        end
      end

      def build_profiles(event_id, user_email_by_id)
        ticket_rows = @connection[:tickets]
          .join(:ticket_types, id: :ticket_type_id)
          .where(Sequel[:ticket_types][:event_id] => event_id)
          .where(Sequel[:tickets][:canceled_at] => nil)
          .select_all(:tickets)
          .order(Sequel[:tickets][:id])
          .all

        seen = {}
        ticket_rows.each_with_object([]) do |row, profiles|
          user_email =
            if row[:user_id]
              user_email_by_id[row[:user_id]]
            else
              row[:email].to_s.downcase.strip.presence
            end
          next unless user_email
          next if seen[user_email]

          seen[user_email] = true
          first_name, last_name = split_name(row[:name].to_s.strip)

          profile = { user_email: user_email }
          profile[:first_name] = first_name if first_name.present?
          profile[:last_name]  = last_name  if last_name.present?
          profile[:phone]      = row[:phone].presence

          profiles << profile.compact
        end
      end

      def admin_staff_positions(event_users)
        admin_emails = @connection[:users]
          .where(admin: true)
          .select(:email)
          .map { |r| r[:email].to_s.downcase.strip }
          .select { |e| e.present? && event_users.any? { |u| u[:email] == e } }

        return [] if admin_emails.empty?

        [{
          name:        'Admin',
          visible:     false,
          permissions: ['update_convention', 'update_cms_content', 'update_event_proposals',
                        'read_event_proposals', 'update_events', 'update_rooms', 'update_schedule'],
          user_emails: admin_emails
        }]
      end

      def default_event_category
        {
          name:             'Event',
          team_member_name: 'Organizer',
          scheduling_ui:    'single_run',
          event_form_title: 'Regular event form'
        }
      end

      def split_name(full_name)
        return ['', ''] if full_name.blank?
        parts = full_name.split(' ', 2)
        [parts[0] || '', parts[1] || '']
      end

      def logger
        Eventlite.logger
      end
    end
  end
end
