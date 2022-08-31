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

      FormResponse.new(success: success, errors: errors, extra: extra)
    end

    private

    attr_reader :success, :account_age, :mfa_method_counts

    # @return [Integer, nil] number of days since the account was confirmed (rounded) or nil if
    # the account was not confirmed
    def track_account_age
      @account_age = if user.confirmed_at
                       (Time.zone.now - user.confirmed_at).seconds.in_days.round
                     end
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
      ActiveRecord::Base.transaction do
        Db::DeletedUser::Create.call(user.id)
        user.destroy!
      end
    end

    def send_push_notifications
      event = PushNotification::AccountPurgedEvent.new(user: user)
      PushNotification::HttpPush.deliver(event)
    end

    def notify_user_via_email_of_deletion
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.account_reset_complete(user, email_address).deliver_now_or_later
      end
    end

    def extra_analytics_attributes
      {
        user_id: user.uuid,
        email: user.email_addresses.take&.email,
        account_age_in_days: account_age,
        mfa_method_counts: mfa_method_counts,
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
      }
    end
  end
end
