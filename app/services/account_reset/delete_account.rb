# frozen_string_literal: true

module AccountReset
  class DeleteAccount
    include ActiveModel::Model
    include GrantedTokenValidator

    def initialize(token, request, analytics)
      @token = token
      @request = request
      @analytics = analytics
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

    attr_reader :success, :account_age, :mfa_method_counts, :request, :analytics

    # @return [Integer, nil] number of days since the account was confirmed (rounded) or nil if
    # the account was not confirmed
    def track_account_age
      return if !user.confirmed_at
      @account_age = (Time.zone.now - user.confirmed_at).seconds.in_days.round
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
        DeletedUser.create_from_user(user)
        user.destroy!
      end
    end

    def send_push_notifications
      event = PushNotification::AccountPurgedEvent.new(user: user)
      PushNotification::HttpPush.deliver(event)
    end

    # rubocop:disable IdentityIdp/MailLaterLinter
    def notify_user_via_email_of_deletion
      user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: user, email_address: email_address).
          account_reset_complete.deliver_now
      end
    end
    # rubocop:enable IdentityIdp/MailLaterLinter

    def profile_components
      user.active_profile.proofing_components if user.identity_verified? && user.active_profile?
    end

    def extra_analytics_attributes
      {
        user_id: user.uuid,
        email: user.email_addresses.take&.email,
        account_age_in_days: account_age,
        account_confirmed_at: user.confirmed_at,
        mfa_method_counts: mfa_method_counts,
        proofing_components: profile_components,
        identity_verified: user.identity_verified?,
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
      }
    end
  end
end
