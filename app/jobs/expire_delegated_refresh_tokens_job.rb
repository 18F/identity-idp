# frozen_string_literal: true

# Deletes the refresh-token rows of delegated-access families that ended more than a day ago.
# A refresh-token row is operational state only: the digest a presented token is looked up by
# and the rotation marks that detect a replay. Once a family has reached its end no refresh under
# it can succeed, and a day later a replay of one of its tokens has nothing left to end, so the
# rows carry no further state. The family's issuance record (TokenExchangeToken) is kept: it is
# the billing and audit evidence of the exchange.
class ExpireDelegatedRefreshTokensJob < ApplicationJob
  queue_as :low

  def perform(_now)
    deleted_count = TokenExchangeRefreshToken.expired_for_purge.in_batches.delete_all

    analytics.delegated_refresh_tokens_expired(deleted_count:)
  end

  private

  def analytics
    Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end
end
