module ArcgisApi::Auth::Refresh

  # Refreshes a token when it's expired
  class RefreshStrategy

    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token]
    def call(auth:, cache:)
      raise 'Method not implemented'
    end
  end
end