# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class StoreOrders < Intercode1::Table
        def initialize(connection, user_con_profile_id_map)
          super(connection)
          @user_con_profile_id_map = user_con_profile_id_map
        end

        private

        def build_record(row)
          email = @user_con_profile_id_map[row[:UserId]]
          return unless email

          {
            id: row[:OrderId].to_s,
            user_email: email,
            status: row[:Status].to_s.downcase,
            payment_amount: { fractional: row[:PaymentCents].to_i, currency_code: 'USD' },
            payment_note: row[:PaymentNote].presence
          }.compact
        end

        def row_id(row) = row[:OrderId]
      end
    end
  end
end
