# frozen_string_literal: true

require 'nokogiri'
require 'reverse_markdown'

module IntercodeImport
  class Markdownifier
    def initialize(logger)
      @logger = logger
    end

    def markdownify(html)
      return nil unless html.present?

      parsed_html =
        begin
          Nokogiri::HTML::DocumentFragment.parse(html)
        rescue StandardError => e
          @logger.warn("Error parsing HTML #{html.inspect}: #{e.message}")
          return html
        end

      convert_youtube_links(parsed_html)

      begin
        ReverseMarkdown.convert(parsed_html.to_html)
      rescue StandardError => e
        @logger.warn("Error converting HTML to Markdown: #{e.message}")
        parsed_html.to_html
      end
    end

    private

    def convert_youtube_links(parsed_html)
      parsed_html.css('object > param[name=movie][value*=youtube]').each do |param|
        m = %r{www\.youtube\.com\/v\/([A-Za-z0-9_-]+)}.match(param['value'])
        param.parent.add_previous_sibling("{% youtube #{m[1]} %}")
        param.parent.remove
      end
    end
  end
end
