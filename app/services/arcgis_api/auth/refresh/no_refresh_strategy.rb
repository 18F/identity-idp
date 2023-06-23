module ArcgisApi::Auth::Refresh
  # Does not attempt to refresh a token when it's expired
  class NoRefreshStrategy < RefreshStrategy
    # rubocop:disable Lint/UnusedMethodArgument
    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token]
    def call(auth:, cache:)
      cache.token_entry
    end
    # rubocop:enable Lint/UnusedMethodArgument
  end
end
