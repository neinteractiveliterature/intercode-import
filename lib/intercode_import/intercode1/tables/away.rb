# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      # Away blocks indicate when attendees are unavailable.
      # Returns a set of emails for users who have any away blocks,
      # which maps to receive_whos_free_emails: false on their profile.
      class Away < Intercode1::Table
        def initialize(connection, user_con_profile_id_map)
          super(connection)
          @user_con_profile_id_map = user_con_profile_id_map
        end

        def export!
          logger.info 'Exporting Away blocks'
          away_cols = dataset.columns.select { |c| c.to_s =~ /\A(Thu|Fri|Sat|Sun)\d\d\z/ }
          return [] if away_cols.empty?

          where_clause = Sequel::SQL::BooleanExpression.from_value_pairs(
            away_cols.map { |c| [c, 1] }, :OR
          )

          dataset.where(where_clause).distinct.select_map(:UserId).filter_map do |user_id|
            @user_con_profile_id_map[user_id]
          end
        end
      end
    end
  end
end
