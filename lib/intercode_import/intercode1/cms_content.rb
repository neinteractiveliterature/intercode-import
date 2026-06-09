# frozen_string_literal: true

require 'base64'
require 'set'

module IntercodeImport
  module Intercode1
    # Exports CMS content (pages, partials, files, navigation) from a legacy
    # Intercode 1 convention into the portable JSON format.
    class CmsContent
      KNOWN_PARTIALS = %w[acceptingbids bidding1 bidearly copyright logintop loginbottom].freeze

      NAVIGATION_STRUCTURE = [
        {
          title: 'About',
          links: [
            { title: 'About Intercon', page_name: 'about' },
            { title: 'Convention Rules', page_name: 'ConRules' },
            { title: 'What Does It Cost?', page_name: 'Cost' },
            { title: 'Contacts', page_name: 'Contacts' },
            { title: 'Hotel Info', page_name: 'hotel' },
            { title: "Who's Who", page_name: "Who's Who" },
            { title: 'Volunteering', page_name: 'volunteering' },
            { title: 'ConCom Schedule', page_name: 'ConCom Schedule' },
            { title: 'Intercon Flyer', page_name: 'Flyer' },
            { title: 'Intercon Program', page_name: 'Program' }
          ]
        }
      ].freeze

      MIME_TYPES = {
        '.jpg' => 'image/jpeg',
        '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.gif' => 'image/gif',
        '.pdf' => 'application/pdf',
        '.svg' => 'image/svg+xml',
        '.webp' => 'image/webp'
      }.freeze

      def initialize(constants_file, config)
        @constants_file = constants_file
        @config = config
        @text_dir = config.var(:text_dir)
        @source_dir = File.dirname(constants_file)
        @local_files = {}
      end

      def export!
        return empty_result unless @text_dir.present? && Dir.exist?(@text_dir)

        cms_pages = []
        cms_partials = []

        Dir[File.join(@text_dir, '*.html')].sort.each do |html_path|
          page_name = File.basename(html_path, '.html')
          logger.info "Exporting CMS content: #{page_name}"

          html = process_php_fragment(html_path)
          result = HtmlConverter.new(html: html, source_dir: @source_dir).convert

          result[:local_files].each { |path| @local_files[File.basename(path)] = path }

          if KNOWN_PARTIALS.include?(page_name)
            cms_partials << { name: page_name, content: result[:content] }
          else
            cms_pages << { name: page_name, slug: slugify(page_name), content: result[:content] }
          end
        end

        {
          cms_pages: cms_pages,
          cms_partials: cms_partials,
          cms_files: encode_local_files,
          cms_navigation_items: build_navigation_items(cms_pages)
        }
      end

      private

      def logger
        Intercode1.logger
      end

      def empty_result
        { cms_pages: [], cms_partials: [], cms_files: [], cms_navigation_items: [] }
      end

      def process_php_fragment(path)
        raw_content = File.read(path)
        php = <<~PHP
          <?php
            error_reporting(E_ERROR);
            date_default_timezone_set("#{php_timezone}");
            require "#{intercon_db_inc_path}";
          ?>
          #{raw_content}
        PHP
        Php.exec_php(php).strip
      end

      def php_timezone
        tz = @config.var(:php_timezone)
        tz ? tz.tzinfo.name : 'UTC'
      end

      def intercon_db_inc_path
        File.join(@source_dir, 'intercon_db.inc')
      end

      def encode_local_files
        @local_files.filter_map do |filename, path|
          next unless File.exist?(path)

          ext = File.extname(filename).downcase
          {
            filename: filename,
            content_base64: Base64.strict_encode64(File.binread(path)),
            content_type: MIME_TYPES[ext] || 'application/octet-stream'
          }
        end
      end

      def build_navigation_items(cms_pages)
        page_names = cms_pages.map { |p| p[:name] }.to_set

        NAVIGATION_STRUCTURE.filter_map do |section|
          links = section[:links].filter_map do |link|
            next unless page_names.include?(link[:page_name])

            { title: link[:title], page_name: link[:page_name] }
          end
          next if links.empty?

          { title: section[:title], links: links }
        end
      end

      def slugify(str)
        str.to_s.downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '').sub(/\A[^a-z]+/, '')
      end
    end
  end
end
