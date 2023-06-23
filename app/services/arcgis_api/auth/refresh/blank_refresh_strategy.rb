module ArcgisApi::Auth::Refresh

  # Does nothing, returns a blank token
  class BlankRefreshStrategy < RefreshStrategy

    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token]
    def call(auth:, cache:)
      ArcgisApi::Auth::Token.new
    end
  end
end