# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class StoreOrderEntries < Intercode1::Table
        def initialize(connection, order_id_map, store_item_id_map)
          super(connection)
          @order_id_map = order_id_map
          @store_item_id_map = store_item_id_map
        end

        def dataset
          super.where(Sequel.lit('Quantity > 0'))
        end

        # Returns {order_id => [entries]} to be merged into store_orders
        def export!
          logger.info 'Exporting StoreOrderEntries'
          by_order = Hash.new { |h, k| h[k] = [] }
          dataset.each do |row|
            order_id = @order_id_map[row[:OrderId]]
            item_name = @store_item_id_map[row[:ItemId]]
            next unless order_id && item_name

            by_order[order_id] << {
              store_item_name: item_name,
              quantity: row[:Quantity].to_i,
              price_per_item: { fractional: row[:PricePerItemCents].to_i, currency_code: 'USD' }
            }
          end
          by_order
        end

        def row_id(row) = row[:OrderEntryId]
      end
    end
  end
end
