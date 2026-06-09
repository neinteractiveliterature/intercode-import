# frozen_string_literal: true

module IntercodeImport
  module Procon
    module UserHelpers
      # Returns the email for a person, creating a user_con_profile entry if needed.
      # profile_accumulator is a Hash of convention_id => Set of {user_email, profile attrs}
      def email_for_person_id(person_id, convention_id, person_id_map, profile_accumulator)
        email = person_id_map[person_id]
        unless email
          logger.warn "Couldn't find user for person id #{person_id}"
          return nil
        end

        unless profile_accumulator[convention_id].any? { |p| p[:user_email] == email }
          person_row = connection[:people].where(id: person_id).first
          profile_accumulator[convention_id] << {
            user_email: email,
            first_name: person_row[:firstname].presence,
            last_name: person_row[:lastname].presence,
            nickname: person_row[:nickname].presence,
            phone: person_row[:phone].presence,
            best_call_time: person_row[:best_call_time].presence,
            birth_date: person_row[:birthdate]&.iso8601
          }.compact
        end

        email
      end
    end
  end
end
