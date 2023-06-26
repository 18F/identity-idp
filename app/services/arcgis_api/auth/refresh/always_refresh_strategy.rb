module ArcgisApi::Auth::Refresh
  # Always refreshes the token
  class AlwaysRefreshStrategy < RefreshStrategy
    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token]
    def call(auth:, cache:)
      token_entry = auth.retrieve_token
      cache.save_token(token_entry)
      token_entry
    end
  end
end
