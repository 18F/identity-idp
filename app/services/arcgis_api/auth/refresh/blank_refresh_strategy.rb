module ArcgisApi::Auth::Refresh
  # Does nothing, returns a blank token
  class BlankRefreshStrategy < RefreshStrategy
    # rubocop:disable Lint/UnusedMethodArgument
    # @param [ArcgisApi::Auth::Authentication] auth
    # @param [ArcgisApi::Auth::Cache::TokenCacheWriter] cache
    # @return [ArcgisApi::Auth::Token]
    def call(auth:, cache:)
      ArcgisApi::Auth::Token.new
    end
    # rubocop:enable Lint/UnusedMethodArgument
  end
end
