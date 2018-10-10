module AccountReset
  class DeleteAccount
    include ActiveModel::Model
    include GrantedTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      track_account_age
      track_mfa_method_counts

      if success
        notify_user_via_email_of_deletion
        destroy_user
      end

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success, :account_age, :mfa_method_counts

    def track_account_age
      @account_age = ((Time.zone.now - user.confirmed_at) / 1.day).round
    end

    def track_mfa_method_counts
      @mfa_method_counts = MfaContext.new(user).enabled_two_factor_configuration_counts_hash
    end

    def destroy_user
      user.destroy!
    end

    def notify_user_via_email_of_deletion
      UserMailer.account_reset_complete(user.email_address.email).deliver_later
    end

    def extra_analytics_attributes
      {
        user_id: user.uuid,
        event: 'delete',
        email: user.email_address.email,
        account_age_in_days: account_age,
        mfa_method_counts: mfa_method_counts,
      }
    end
  end
end
