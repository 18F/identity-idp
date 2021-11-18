module Reports
  module QueryHelpers
    def quote(value)
      if value.is_a?(Array)
        "(#{value.map { |v| ActiveRecord::Base.connection.quote(v) }.join(', ')})"
      else
        ActiveRecord::Base.connection.quote(value)
      end
    end

    # Wrapper around PG::Result#stream_each, runs a query and yields each row to the block
    # as it is returned from the DB
    # @param [String] SQL query
    # @yieldparam [Hash] row
    def stream_query(query)
      ActiveRecord::Base.logger.debug(query) # using send_query skips ActiveRecord logging
      connection = ActiveRecord::Base.connection.raw_connection
      connection.send_query(query)
      connection.set_single_row_mode
      connection.get_result.stream_each do |row|
        yield row
      end
      connection.get_result
    end
  end
end
