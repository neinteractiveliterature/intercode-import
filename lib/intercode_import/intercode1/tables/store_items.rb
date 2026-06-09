# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class StoreItems < Intercode1::Table
        def initialize(connection)
          super
        end

        private

        def build_record(row)
          name = [row[:Gender], row[:Color], row[:Style], row[:Singular]].select(&:present?).join(' ')
          {
            id: row[:ItemId].to_s,
            name: name,
            description: "A #{name.downcase} with the convention logo.",
            available: yn_to_bool(row[:Available], true),
            price: { fractional: row[:PriceCents].to_i, currency_code: 'USD' }
          }
        end

        def row_id(row) = row[:ItemId]
      end
    end
  end
end
