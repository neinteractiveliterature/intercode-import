# frozen_string_literal: true

require 'tempfile'
require 'open3'

module IntercodeImport
  module Intercode1
    module Php
      def self.exec_php(php, filename = 'program.php')
        temp_program = Tempfile.new(filename)
        begin
          temp_program.write php
          temp_program.flush
          output, = Open3.capture2('php', '-d', 'display_errors=stderr', '-d', 'short_open_tag=1', temp_program.path)
          output
        ensure
          temp_program.close
          temp_program.unlink
        end
      end
    end
  end
end
