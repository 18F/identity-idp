module ArcgisApi::Cache

  # Applies a sliding window strategy to reduce contention
  # related to refreshing the token
  class SlidingWindowTokenKeeper

    # Delegate public token method
    delegate :token, to: :token_cache

    # @param [#retrieve_token,#save_token] token_cache
    def initialize(token_cache:)
      @token_cache = token_cache
    end

    def refresh_token

    end

    private
    # Explicitly delegate required methods
    delegate :retrieve_token, :save_token, :token_entry, to: :token_cache

    attr_accessor :token_cache
  end
end