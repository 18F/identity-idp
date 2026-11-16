# frozen_string_literal: true

# Deletes token exchange refresh tokens once their family has passed its absolute lifetime. Used
# and revoked rows are kept until then, because reuse detection needs to recognize a used token
# for as long as its family could otherwise be refreshed.
class ExpireTokenExchangeRefreshTokensJob < ApplicationJob
  queue_as :low

  def perform(now)
    deleted_count = TokenExchangeRefreshToken.family_expired(now).in_batches.delete_all

    analytics.token_exchange_refresh_tokens_expired(deleted_count:)
  end

  private

  def analytics
    Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end
end
