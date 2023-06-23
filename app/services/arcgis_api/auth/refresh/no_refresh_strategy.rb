module ArcgisApi::Auth::Refresh

  # Does not attempt to refresh a token when it's expired
  class NoRefreshStrategy < RefreshStrategy

    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token]
    def call(auth:, cache:)
      cache.token_entry
    end
  end
end