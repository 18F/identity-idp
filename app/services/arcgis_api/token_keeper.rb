module ArcgisApi
  # Class to retrieve, refresh and manage caching of Arcgis API token.
  # If token synchronous fetching is disabled, a token will be fetched from
  # cache directly or it will be a cache miss.
  # Otherwise the thread will try to fetch/refresh the token on demand as needed.
  class TokenKeeper
    def initialize(auth: nil, cache: nil)
      @auth = auth || ArcgisApi::Auth::Authentication.new

      if arcgis_token_sliding_expiration_enabled
        @cache = cache || ArcgisApi::Auth::Cache::TokenCacheInfoWriter.new
      else
        # Use backwards-compatible cache until we have sliding expiration
        # enabled.
        @cache = cache || ArcgisApi::Auth::Cache::TokenCacheRawWriter.new
      end
    end

    # Refresh the token if needed. For use when deliberately trying
    # to refresh the token without attempting an additional request.
    def refresh_token
      refresh_strategy.call(auth:, cache:)
    end

    # Refresh the token when needed, then return the token. For
    # use when calling through from another request to refresh
    # the token.
    #
    # @return [String] token
    def token
      thru_strategy.call(auth:, cache:)&.token
    end

    private

    def refresh_strategy
      @refresh_strategy ||= begin
        if arcgis_token_refresh_job_enabled
          ArcgisApi::Auth::Refresh::AlwaysRefreshStrategy.new
        else
          ArcgisApi::Auth::Refresh::NoopRefreshStrategy.new
        end
      end
    end

    def thru_strategy
      @thru_strategy ||= begin
        if arcgis_token_sync_request_enabled
          if arcgis_token_sliding_expiration_enabled
            ArcgisApi::Auth::Refresh::SlidingWindowRefreshStrategy.new
          else
            ArcgisApi::Auth::Refresh::OnExpireRefreshStrategy.new
          end
        else
          ArcgisApi::Auth::Refresh::FetchWithoutRefreshStrategy.new
        end
      end
    end

    delegate :arcgis_token_sliding_expiration_enabled,
             :arcgis_token_sync_request_enabled,
             :arcgis_token_refresh_job_enabled,
             to: :"IdentityConfig.store"

    attr_accessor :auth, :cache
  end
end
