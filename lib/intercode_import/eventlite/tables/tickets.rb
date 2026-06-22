# frozen_string_literal: true

module IntercodeImport
  module Eventlite
    module Tables
      class Tickets < Eventlite::Table
        def initialize(connection, event_id, ticket_type_name_by_id, user_email_by_id)
          super(connection)
          @event_id = event_id
          @ticket_type_name_by_id = ticket_type_name_by_id
          @user_email_by_id = user_email_by_id
        end

        def dataset
          connection[:tickets]
            .join(:ticket_types, id: :ticket_type_id)
            .where(Sequel[:ticket_types][:event_id] => @event_id)
            .where(Sequel[:tickets][:canceled_at] => nil)
            .select_all(:tickets)
        end

        def export!
          logger.info "Exporting Tickets for event #{@event_id}"
          results = []

          dataset.each do |row|
            user_email = @user_email_by_id[row[:user_id]]
            next unless user_email

            ticket_type_name = @ticket_type_name_by_id[row[:ticket_type_id]]
            next unless ticket_type_name

            results << { user_email: user_email, ticket_type_name: ticket_type_name }
          end

          results
        end
      end
    end
  end
end
