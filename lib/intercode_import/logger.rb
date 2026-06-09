# frozen_string_literal: true

require 'logger'
require 'singleton'

module IntercodeImport
  class Logger < ::Logger
    include Singleton

    SEVERITY_COLORS = {
      'FATAL' => "\e[31m",
      'ERROR' => "\e[31m",
      'WARN'  => "\e[33m",
      'INFO'  => "\e[32m",
      'DEBUG' => "\e[34m"
    }.freeze
    RESET = "\e[0m"

    def initialize
      super($stderr)
      self.level = ENV['DEBUG'] ? ::Logger::DEBUG : ::Logger::INFO
      self.formatter = proc do |severity, datetime, _progname, msg|
        color = SEVERITY_COLORS[severity] || ''
        "#{color}[#{datetime.strftime('%H:%M:%S')}] #{severity}: #{msg}#{RESET}\n"
      end
    end
  end
end
