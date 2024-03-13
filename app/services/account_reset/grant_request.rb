module AccountReset
  class GrantRequest
    def initialize(user)
      @user_id = user.id
    end

    def call
      token = SecureRandom.uuid
      arr = AccountResetRequest.find_by(user_id: @user_id)
      return if fraud_user?(arr) && fraud_wait_not_met?(arr)
      result = arr.with_lock do
        if !arr.granted_token_valid?
          arr.update(
            granted_at: Time.zone.now,
            granted_token: token,
          )
        end
      end

      !!result
    end

    private

    def fraud_user?(arr)
      arr.user.fraud_review_pending? ||
        arr.user.fraud_rejection?
    end

    def fraud_user_and_fraud_with_not_met(arr)
    end

    def fraud_wait_period_not_met?(now)
      if fraud_wait_period_days.present?
        return arr.requested_at > (now - fraud_wait_period_days.days)
      else
        false
      end
    end

    def fraud_wait_period_days
      IdentityConfig.store.account_reset_fraud_user_wait_period_days
    end
  end
end
