module ArcgisApi::Token::Refresh

  # Refreshes a token when it's expired
  class OnExpireRefreshStrategy < RefreshStrategy

    # @param [ArcgisApi::Token::Authentication] auth
    # @param [ArcgisApi::Token::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Token::TokenInfo]
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