module AccountReset
  class GrantRequest
    def initialize(user)
      @user_id = user.id
    end

    def call
      token = SecureRandom.uuid
      arr = AccountResetRequest.find_by(user_id: @user_id)
      result = arr.with_lock do
        if !arr.granted_token_valid?
          account_reset_request.update(
            granted_at: Time.zone.now,
            granted_token: token,
          )
        end
      end

      !!result
    end

    private

    def account_reset_request
      AccountResetRequest.create_or_find_by(user_id: @user_id)
    end
  end
end
