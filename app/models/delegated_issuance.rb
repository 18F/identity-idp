# frozen_string_literal: true

# One immutable delegated access token issuance. A new row is written for every DAT minted,
# even when the same user, actor and target have appeared in earlier issuances.
class DelegatedIssuance < ApplicationRecord
  DELEGATION_ID_PREFIX = 'dlg_'

  belongs_to :user
  belongs_to :actor_return_log, class_name: 'SpReturnLog'
  belongs_to :target_return_log, class_name: 'SpReturnLog'

  validates :delegation_id, :actor_issuer, :target_issuer, :resource,
            :issued_at, :expires_at, presence: true
  validates :delegation_id, uniqueness: true
  validate :return_logs_match_issuance

  def self.generate_delegation_id
    DELEGATION_ID_PREFIX + SecureRandom.urlsafe_base64(16)
  end

  def readonly?
    persisted?
  end

  private

  def return_logs_match_issuance
    validate_return_log(actor_return_log, actor_issuer, :actor_return_log)
    validate_return_log(target_return_log, target_issuer, :target_return_log)
  end

  def validate_return_log(return_log, issuer, attribute)
    return if return_log.blank?

    errors.add(attribute, :invalid) if return_log.user_id != user_id || return_log.issuer != issuer
  end
end
