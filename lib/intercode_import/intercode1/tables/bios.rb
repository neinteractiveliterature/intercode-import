# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class Bios < Intercode1::Table
        def initialize(connection, user_con_profile_id_map)
          super(connection)
          @user_con_profile_id_map = user_con_profile_id_map
          @markdownifier = IntercodeImport::Markdownifier.new(logger)
        end

        # Bios update existing user_con_profile records rather than producing new ones.
        # Returns a hash of email => bio attributes to be merged into user_con_profiles.
        def export!
          logger.info 'Exporting Bios'
          updates = {}
          dataset.each do |row|
            email = @user_con_profile_id_map[row[:UserId]]
            next unless email

            title = row[:Title].presence
            title = "*#{title}*<br>\n" if title
            body = @markdownifier.markdownify(row[:BioText])
            bio = [title, body].compact.join('')

            updates[email] = {
              bio: bio,
              show_nickname_in_bio: row[:ShowNickname] != 0
            }
          end
          updates
        end

        private

        def row_id(row) = row[:BioId]
      end
    end
  end
end
