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

      extra = extra_analytics_attributes

      handle_successful_submission if success

      FormResponse.new(success: success, errors: errors.messages, extra: extra)
    end

    private

    attr_reader :success, :account_age, :mfa_method_counts

    def track_account_age
      @account_age = ((Time.zone.now - user.confirmed_at) / 1.day).round
    end

    def track_mfa_method_counts
      @mfa_method_counts = MfaContext.new(user).enabled_two_factor_configuration_counts_hash
    end

    def handle_successful_submission
      notify_user_via_email_of_deletion
      send_push_notifications
      destroy_user
    end

    def destroy_user
      user.destroy!
    end

    def send_push_notifications
      return if Figaro.env.push_notifications_enabled != 'true'
      PushNotification::AccountDelete.new.call(user.id)
    end

    def notify_user_via_email_of_deletion
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.account_reset_complete(email_address).deliver_later
      end
    end

    def extra_analytics_attributes
      {
        user_id: user.uuid,
        event: 'delete',
        email: user.email_addresses.take&.email,
        account_age_in_days: account_age,
        mfa_method_counts: mfa_method_counts,
      }
    end
  end
end
