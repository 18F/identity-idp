module ArcgisApi::Auth::Refresh
  # Refreshes a token when it's expired
  class RefreshStrategy
    # rubocop:disable Lint/UnusedMethodArgument
    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token,nil]
    def call(auth:, cache:)
      raise 'Method not implemented'
    end
    # rubocop:enable Lint/UnusedMethodArgument
  end
end
