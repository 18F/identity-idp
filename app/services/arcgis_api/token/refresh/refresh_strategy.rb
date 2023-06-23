module ArcgisApi::Token::Refresh

  # Refreshes a token when it's expired
  class RefreshStrategy

    # @param [ArcgisApi::Token::Authentication] auth
    # @param [ArcgisApi::Token::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Token::TokenInfo]
    def call(auth:, cache:)
      raise 'Method not implemented'
    end
  end
end