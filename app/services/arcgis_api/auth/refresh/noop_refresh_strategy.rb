module ArcgisApi::Auth::Refresh
  # Does nothing, returns nil
  class NoopRefreshStrategy < RefreshStrategy
    # rubocop:disable Lint/UnusedMethodArgument
    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [nil]
    def call(auth:, cache:)
      nil
    end
    # rubocop:enable Lint/UnusedMethodArgument
  end
end
