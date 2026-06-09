# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Con < Intercode1::Table
        def initialize(connection, config)
          super(connection)
          config = config.symbolize_keys
          @con_name   = config[:con_name]
          @con_domain = config[:con_domain]
          @maximum_tickets = config[:maximum_tickets]

          timezone = ActiveSupport::TimeZone[config[:timezone_name]]
          friday_date = config[:friday_date]
          friday_start = timezone.local(friday_date.year, friday_date.month, friday_date.day)

          unless friday_start.friday?
            raise "FRI_DATE is not a Friday: #{friday_start.strftime('%A, %b %d, %Y')}"
          end

          @starts_at = config[:thursday_enabled] ? (friday_start - 1.day).change(hour: 18) : friday_start
          @ends_at   = (friday_start + 2.days).change(hour: 15)
          @timezone  = timezone
          @row       = dataset.first
        end

        def export_convention
          row = @row
          {
            name: @con_name,
            domain: @con_domain,
            timezone_name: @timezone.name,
            ticket_mode: 'required_for_signup',
            site_mode: 'convention',
            starts_at: @starts_at.iso8601,
            ends_at: @ends_at.iso8601,
            show_schedule: row[:ShowSchedule].underscore,
            maximum_tickets: @maximum_tickets,
            maximum_event_signups: {
              timespans: [{ start: nil, finish: nil, value: row[:SignupsAllowed].underscore }]
            }
          }
        end

        private

        def dataset
          connection[:Con]
        end
      end
    end
  end
end
