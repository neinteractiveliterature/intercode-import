# frozen_string_literal: true

module IntercodeImport
  class Table
    attr_reader :connection, :id_map

    def initialize(connection)
      @connection = connection
      @id_map = {}
    end

    def table_name
      self.class.name.demodulize.to_sym
    end

    def dataset
      connection[table_name]
    end

    def object_name
      @object_name ||= self.class.name.demodulize.singularize
    end

    def export!
      logger.info "Exporting #{object_name.pluralize}"
      results = []
      dataset.each do |row|
        logger.debug "Exporting #{object_name} #{row_id(row)}"
        record = build_record(row)
        next unless record

        id_map[row_id(row)] = record[:id] || row_id(row).to_s
        results << record
      end
      results
    end

    private

    def build_record(_row) = nil
    def row_id(_row) = nil

    def logger
      IntercodeImport::Logger.instance
    end
  end
end
