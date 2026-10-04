# frozen_string_literal: true

# Per-broker token-exchange state for the account page: which of the user's
# linked applications the broker may act at (each with its own grant), grouped
# by agency, plus the auto-enroll setting.
class TokenExchangeBrokerPresenter
  attr_reader :user, :broker

  def initialize(user:, broker:)
    @user = user
    @broker = broker
  end

  # @return [Array<[Agency, Array<ServiceProvider>]>]
  def linked_targets_by_agency
    @linked_targets_by_agency ||= TokenExchangeReachableTargets.grouped_by_agency(linked_targets)
  end

  # @return [Array<ServiceProvider>]
  def linked_targets
    @linked_targets ||= TokenExchangeReachableTargets.linked_for(
      user: user, broker_issuer: broker.issuer,
    )
  end

  def any_linked_targets?
    linked_targets.any?
  end

  # @return [TokenExchangeGrant, nil] the active grant for a target, if any
  def grant_for(target)
    active_grants_by_target[target.issuer]
  end

  def granted?(target)
    grant_for(target).present?
  end

  def auto_enroll_enabled?
    setting.auto_enroll_enabled?
  end

  def auto_enroll_granted_at
    setting.auto_enroll_granted_at
  end

  private

  def setting
    @setting ||= TokenExchangeBrokerSetting.for(user: user, broker_issuer: broker.issuer)
  end

  def active_grants_by_target
    @active_grants_by_target ||= TokenExchangeGrant.active
      .where(user: user, broker_issuer: broker.issuer)
      .index_by(&:target_issuer)
  end
end
