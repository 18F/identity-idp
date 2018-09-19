module AccountReset
  class GrantRequest
    def initialize(user)
      @user_id = user.id
    end

    def call
      token = SecureRandom.uuid
      arr = AccountResetRequest.find_by(user_id: @user_id)
      arr.with_lock do
        return false if arr.granted_token_valid?
        account_reset_request.update(granted_at: Time.zone.now,
                                     granted_token: token)
      end
      true
    end

    private

    def account_reset_request
      AccountResetRequest.find_or_create_by(user_id: @user_id)
    end
  end
end
