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
      @mfa_method_counts = mfa_methods.empty? ? {} : mfa_method_counts_hash
    end

    def mfa_method_counts_hash
      mfa_methods.each_with_object(Hash.new(0)) { |name, count| count[name] += 1 }
    end

    def mfa_methods
      @mfa_methods ||= MfaContext.new(user).two_factor_configurations.map(&:name).compact
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
