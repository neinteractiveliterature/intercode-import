# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class GMs < Intercode1::Table
        BOOL_FIELD_MAP = {
          display: :DisplayAsGM, show_email: :DisplayEMail, receive_con_email: :ReceiveConEMail
        }.freeze

        def initialize(connection, event_id_map, user_con_profile_id_map)
          super(connection)
          @event_id_map = event_id_map
          @user_con_profile_id_map = user_con_profile_id_map
          @seen = {}
        end

        private

        def build_record(row)
          event_id   = @event_id_map[row[:EventId]]
          user_email = @user_con_profile_id_map[row[:UserId]]
          return unless event_id && user_email

          key = "#{event_id}:#{user_email}"
          if @seen[key]
            BOOL_FIELD_MAP.each { |field, col| @seen[key][field] ||= row[col] }
            return nil
          end

          record = {
            event_id: event_id,
            user_email: user_email,
            display: row[:DisplayAsGM] || false,
            show_email: row[:DisplayEMail] || false,
            receive_con_email: row[:ReceiveConEMail] || false,
            receive_signup_email: row[:ReceiveSignupEMail] ? 'all_signups' : 'no'
          }
          @seen[key] = record
          record
        end

        def row_id(row) = row[:GMId]
      end
    end
  end
end
