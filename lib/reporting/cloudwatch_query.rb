module Reporting
  # Helper for constructing Cloudwatch Insights queries for common patterns
  class CloudwatchQuery
    MAX_LIMIT = 10_000

    attr_reader :names, :service_provider, :limit

    # @param [Array<String>] names
    # @param [String] service_provider issuer
    def initialize(names: [], service_provider: nil, limit: MAX_LIMIT)
      @names = names
      @service_provider = service_provider
      @limit = limit
    end

    def to_query
      [
        'fields @message, @timestamp',
        *service_provider_filter,
        *names_filter,
        *limit_filter,
      ].join("\n")
    end

    alias_method :to_s, :to_query

    module Quoting
      # Quotes a string or array to be used as a literal
      # @param [String,Array<String>] str_or_ary
      def quote(str_or_ary)
        if str_or_ary.is_a?(Array)
          '[' + str_or_ary.map { |str| quote(str) }.join(',') + ']'
        else
          %|"#{str_or_ary.gsub('"', '\"')}"|
        end
      end

      alias_method :q, :quote
    end

    include Quoting

    private

    def service_provider_filter
      "| filter properties.service_provider = #{q(service_provider)}" if service_provider.present?
    end

    def names_filter
      if names.present?
        "| filter name in #{q(names)}"
      end
    end

    def limit_filter
      "| limit #{limit}" if limit.present?
    end
  end
end
