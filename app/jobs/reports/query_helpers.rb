module Reports
  module QueryHelpers
    def quote(value)
      if value.is_a?(Array)
        "(#{value.map { |v| ActiveRecord::Base.connection.quote(v) }.join(', ')})"
      else
        ActiveRecord::Base.connection.quote(value)
      end
    end
  end
end
