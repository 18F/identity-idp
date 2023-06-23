module ArcgisApi::Auth::Refresh

  # Refreshes a token when it's expired
  class OnExpireRefreshStrategy < RefreshStrategy

    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token]
    def call(auth:, cache:)
      token_entry = cache.token_entry
      if token_entry.nil? || token_entry.expired?
        token_entry = auth.retrieve_token
        cache.save_token(token_entry)
      end
      token_entry
    end
  end
end