# frozen_string_literal: true

require 'net/http'
require 'base64'
require 'uri'

module IntercodeImport
  module Eventlite
    module Tables
      class CmsFiles < Eventlite::Table
        def initialize(connection, event_id, file_base_url)
          super(connection)
          @event_id = event_id
          @file_base_url = file_base_url
        end

        def dataset
          connection[:cms_files].where(
            Sequel.lit('(parent_type = ? AND parent_id = ?) OR parent_type IS NULL', 'Event', @event_id)
          )
        end

        def export!
          unless @file_base_url
            logger.warn 'FILE_BASE_URL not set; skipping CMS file export'
            return []
          end

          logger.info "Exporting CmsFiles for event #{@event_id}"
          results = []

          dataset.each do |row|
            filename = row[:file].to_s
            next if filename.blank?

            # CarrierWave store_dir: uploads/cms_file/file/{id}/{filename}
            file_path = "uploads/cms_file/file/#{row[:id]}/#{filename}"
            url = @file_base_url.chomp('/') + '/' + file_path

            content, content_type = fetch_file(url)
            next unless content

            results << {
              filename: filename,
              content_base64: Base64.strict_encode64(content),
              content_type: content_type || 'application/octet-stream'
            }
          end

          results
        end

        private

        def fetch_file(url)
          uri = URI.parse(url)
          response = Net::HTTP.get_response(uri)

          unless response.is_a?(Net::HTTPSuccess)
            logger.warn "Failed to fetch #{url}: #{response.code} #{response.message}"
            return nil
          end

          content_type = response['Content-Type']&.split(';')&.first&.strip
          [response.body, content_type]
        rescue StandardError => e
          logger.warn "Error fetching #{url}: #{e.message}"
          nil
        end
      end
    end
  end
end
