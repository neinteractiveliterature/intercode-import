# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'intercode_import'
require 'intercode_import/intercode1'
require 'intercode_import/procon'
require 'intercode_import/illyan'
require 'intercode_import/eventlite'

def fetch_env!(name)
  value = ENV[name].presence
  abort "Please set the #{name} environment variable" unless value
  value
end

def write_output(data, default_filename)
  output_file = ENV['OUTPUT_FILE'] || default_filename
  json = JSON.pretty_generate(data)
  if output_file == '-'
    puts json
  else
    File.write(output_file, json)
    puts "Wrote #{output_file}"
  end
end

namespace :export do
  desc 'Export an Intercode 1 database to the convention JSON format'
  task :intercode1 do
    exporter = IntercodeImport::Intercode1::Exporter.new(
      fetch_env!('CONSTANTS_FILE'),
      con_domain: ENV['CON_DOMAIN']
    )
    exporter.build_password_hashes
    data = exporter.export
    write_output(data, 'convention-export.json')
  end

  desc 'Export ProCon conventions to convention JSON format (one file per matched convention)'
  task :procon do
    exporter = IntercodeImport::Procon::Exporter.new(
      fetch_env!('PROCON_DB_URL'),
      fetch_env!('ILLYAN_DB_URL'),
      fetch_env!('CONVENTION_DOMAIN_REGEX'),
      fetch_env!('ORGANIZATION_NAME')
    )
    conventions = exporter.export
    conventions.each_with_index do |data, i|
      domain = data[:convention][:domain].tr('.', '-')
      default_name = "convention-export-#{domain}.json"
      output_file = conventions.size == 1 ? (ENV['OUTPUT_FILE'] || default_name) : default_name
      json = JSON.pretty_generate(data)
      if output_file == '-'
        puts json
      else
        File.write(output_file, json)
        puts "Wrote #{output_file} (#{data[:convention][:name]})"
      end
    end
  end

  desc 'Export Eventlite events to convention JSON format (one file per event)'
  task :eventlite do
    exporter = IntercodeImport::Eventlite::Exporter.new(
      fetch_env!('EVENTLITE_DB_URL'),
      domain_suffix: ENV['DOMAIN_SUFFIX'] || 'example.com',
      timezone: ENV['TIMEZONE'] || 'UTC',
      file_base_url: ENV['FILE_BASE_URL']
    )
    exports = exporter.export
    exports.each do |data|
      domain = data[:convention][:domain].tr('.', '-')
      default_name = "convention-export-#{domain}.json"
      output_file = exports.size == 1 ? (ENV['OUTPUT_FILE'] || default_name) : default_name
      json = JSON.pretty_generate(data)
      if output_file == '-'
        puts json
      else
        File.write(output_file, json)
        puts "Wrote #{output_file} (#{data[:convention][:name]})"
      end
    end
  end

  desc 'Export users from an Illyan database'
  task :illyan do
    emails = fetch_env!('EMAILS').strip.split(/\s+/)
    users = IntercodeImport::Illyan::Exporter.new(
      fetch_env!('ILLYAN_DB_URL'), emails
    ).export
    write_output({ users: users }, 'illyan-users.json')
  end
end
