# frozen_string_literal: true

require 'nokogiri'
require 'set'
require 'uri'

module IntercodeImport
  module Intercode1
    # Converts legacy Intercode 1 HTML content to Liquid markup.
    # Translates internal PHP static-page links to {% page_url %} tags,
    # and collects referenced local image/PDF paths so the caller can
    # base64-encode them as CMS file attachments.
    #
    # Returns a hash: { content: liquid_string, local_files: Set<abs_path> }
    class HtmlConverter
      attr_reader :html, :source_dir

      def initialize(html:, source_dir:)
        @html = html
        @source_dir = source_dir
        @local_files = Set.new
      end

      def convert
        doc = Nokogiri::HTML::DocumentFragment.parse(html, 'UTF-8')

        doc.css('a[href]').each do |link|
          if link['href'].to_s =~ /\.pdf\z/i
            mark_local_file(link, 'href')
          else
            link['href'] = intercode2_path_for_link(link['href'].to_s)
          end
        end

        doc.css('iframe').each { |iframe| iframe['src'] = iframe['src'].to_s.gsub("\r\n", '') }

        doc.css('img').each { |img| mark_local_file(img, 'src') }

        doc.css('h1, h2, h3').each { |h| h['class'] = [h['class'], 'my-3'].compact.join(' ') }
        doc.css('h4, h5, h6').each { |h| h['class'] = [h['class'], 'my-2'].compact.join(' ') }

        content =
          doc
            .to_s
            .gsub(/__PAGE_URL_(\w+)/, '{% page_url \1 %}')
            .gsub(/__CMS_FILE_URL_([^"]+)/, '{% file_url "\1" %}')

        { content: content, local_files: @local_files }
      end

      private

      def mark_local_file(node, attr)
        path = local_file_path(node[attr].to_s)
        return unless path

        @local_files << path
        node[attr] = "__CMS_FILE_URL_#{File.basename(node[attr].to_s)}"
      end

      def local_file_path(url)
        return nil if url.blank?

        begin
          parsed = URI.parse(url)
          return nil if parsed.scheme.present?
          return nil if parsed.path.blank?

          path = File.expand_path(parsed.path, source_dir)
          File.exist?(path) ? path : nil
        rescue URI::InvalidURIError
          nil
        end
      end

      def intercode2_path_for_link(url)
        case url
        when /\A\\"(.*)\\\"\z/
          intercode2_path_for_link(::Regexp.last_match(1))
        when /ConComSchedule\.php/
          '__PAGE_URL_con_com_schedule'
        when /[Ss]tatic\.php\?page=(\w+)/
          "__PAGE_URL_#{slugify(::Regexp.last_match(1))}"
        else
          url
        end
      end

      def slugify(str)
        str.to_s.downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '').sub(/\A[^a-z]+/, '')
      end
    end
  end
end
