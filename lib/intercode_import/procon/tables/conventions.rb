# frozen_string_literal: true

module IntercodeImport
  module Procon
    module Tables
      class Conventions < Procon::Table
        include EventHelpers

        def initialize(connection, convention_domain_regex, organization_name)
          super(connection)
          @convention_domain_regex = convention_domain_regex
          @organization_name = organization_name
        end

        def table_name = :events

        def dataset
          super.where(parent_id: nil)
        end

        private

        def build_record(row)
          return nil unless convention_domain_regex_matches?(row[:id])

          domain = convention_domain(row[:id])
          unless domain
            logger.warn "Skipping #{row[:fullname]}: no virtual sites"
            return nil
          end

          site_mode = site_mode(row[:id])
          max_signups = maximum_event_signups(row)

          {
            id: row[:id].to_s,
            name: row[:fullname],
            domain: domain,
            timezone_name: 'America/New_York',
            ticket_mode: 'disabled',
            site_mode: site_mode,
            starts_at: force_timezone(row[:start], 'America/New_York').iso8601,
            ends_at: force_timezone(row[:end], 'America/New_York').iso8601,
            show_schedule: 'yes',
            show_event_list: 'yes',
            maximum_event_signups: { always: max_signups },
            organization_name: @organization_name,
            cms_content_set: site_mode == 'convention' ? 'procon_import' : 'single_event',
            event_categories: event_categories_for(site_mode),
            default_layout_content: custom_layout_content(domain)
          }.compact
        end

        def site_mode(convention_id)
          connection[:events].where(parent_id: convention_id).any? ? 'convention' : 'single_event'
        end

        def convention_domain_regex_matches?(event_id)
          connection[:virtual_sites].where(event_id: event_id).map(:domain).any? do |d|
            @convention_domain_regex.match?(d)
          end
        end

        def convention_domain(event_id)
          all_domains = connection[:virtual_sites].where(event_id: event_id).map(:domain)
          all_domains.sort_by { |d| [d.length, d] }.last
        end

        def maximum_event_signups(row)
          max = row[:max_child_event_attendances]
          return 'unlimited' if max.nil?
          return 'not_yet'   if max <= 0
          return max.to_s    if max < 4
          'unlimited'
        end

        def event_categories_for(site_mode)
          larp = {
            name: 'Larp',
            team_member_name: 'GM',
            scheduling_ui: site_mode == 'convention' ? 'regular' : 'single_run',
            event_form_title: 'Regular event form',
            event_proposal_form_title: site_mode == 'convention' ? 'Proposal form' : nil
          }.compact

          return [larp] if site_mode == 'single_event'

          con_services = {
            name: 'Con services',
            team_member_name: 'team member',
            scheduling_ui: 'single_run',
            event_form_title: 'Filler event form'
          }

          [larp, con_services]
        end

        def custom_layout_content(domain)
          virtual_site = connection[:virtual_sites].where(domain: domain).first
          return nil unless virtual_site&.dig(:site_template_id)

          site_template = connection[:site_templates].where(id: virtual_site[:site_template_id]).first
          return nil unless site_template

          build_layout_content(site_template)
        end

        def build_layout_content(site_template)
          inner =
            if site_template[:footer].blank?
              <<~HTML
                <div class="container">{{ content_for_navbar }}</div>
                <div class="container bg-white py-4">{{ content_for_layout }}</div>
              HTML
            else
              "{{ content_for_navbar }}\n{{ content_for_layout }}\n"
            end

          css = (site_template[:css] || site_template[:themeroller_css] || '')
                  .gsub('a, a:visited, a:hover {', 'a {')

          <<~HTML
            <!DOCTYPE html><html lang="en"><head>{{ content_for_head }}
            <style>#{css}</style></head><body>
            #{site_template[:header]}#{inner}#{site_template[:footer]}
            </body></html>
          HTML
        end
      end
    end
  end
end
