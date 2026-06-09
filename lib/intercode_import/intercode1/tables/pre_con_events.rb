# frozen_string_literal: true

module IntercodeImport
  module Intercode1
    module Tables
      class PreConEvents < Intercode1::Table
        include RegistrationPolicyHelpers

        def initialize(connection)
          super
          @markdownifier = IntercodeImport::Markdownifier.new(logger)
          @seen_titles = Hash.new(0)
        end

        def dataset
          super.where(Status: %w[Accepted Dropped])
        end

        private

        def build_record(row)
          {
            id: "precon_#{row[:PreConEventId]}",
            title: unique_title(row[:Title].to_s),
            event_category_name: 'panel',
            status: row[:Status] == 'Accepted' ? 'active' : 'dropped',
            con_mail_destination: 'gms',
            length_seconds: row[:Hours].to_i * 3600,
            can_play_concurrently: true,
            description: @markdownifier.markdownify(row[:Description]),
            short_blurb: @markdownifier.markdownify(row[:ShortDescription]),
            registration_policy: unlimited_registration_policy
          }.compact
        end

        def row_id(row) = row[:PreConEventId]

        def unique_title(title)
          @seen_titles[title] += 1
          count = @seen_titles[title]
          count == 1 ? title : "#{title} [#{count}]"
        end
      end
    end
  end
end
