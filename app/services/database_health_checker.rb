module DatabaseHealthChecker
  module_function

  Summary = Struct.new(:healthy, :result) do
    def as_json(*args)
      to_h.as_json(*args)
    end

    alias_method :healthy?, :healthy
  end

  # @return [Summary]
  def check
    Summary.new(true, simple_query)
  rescue => err
    NewRelic::Agent.notice_error(err)
    Summary.new(false, err.message)
  end

  # @api private
  def simple_query
    ActiveRecord::Base.connection.select_values(sql_command)
  end

  # @api private
  def sql_command
    'SELECT 1'
  end
end
