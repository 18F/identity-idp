module ArcgisApi::Token::Refresh

  # Does not attempt to refresh a token when it's expired
  class NoRefreshStrategy < RefreshStrategy

    # @param [ArcgisApi::Token::Authentication] auth
    # @param [ArcgisApi::Token::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Token::TokenInfo]
    def call(auth:, cache:)
      cache.token_entry
    end
  end
end