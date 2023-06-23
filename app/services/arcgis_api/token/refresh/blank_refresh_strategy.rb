module ArcgisApi::Token::Refresh

  # Does nothing, returns a blank token
  class BlankRefreshStrategy < RefreshStrategy

    # @param [ArcgisApi::Token::Authentication] auth
    # @param [ArcgisApi::Token::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Token::TokenInfo]
    def call(auth:, cache:)
      ArcgisApi::Token::TokenInfo.new
    end
  end
end