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
      track_identity_verified_status
      track_identity_verification_pending

      extra = extra_analytics_attributes

      handle_successful_submission if success

      FormResponse.new(success: success, errors: errors, extra: extra)
    end

    private

    attr_reader :success, :account_age, :mfa_method_counts, :request, :analytics, :verified_status,
                :verification_method

    # @return [Integer, nil] number of days since the account was confirmed (rounded) or nil if
    # the account was not confirmed
    def track_account_age
      return if !user.confirmed_at
      @account_age = (Time.zone.now - user.confirmed_at).seconds.in_days.round
    end

    def track_mfa_method_counts
      @mfa_method_counts = MfaContext.new(user).enabled_two_factor_configuration_counts_hash
    end

    def track_identity_verified_status
      @verified_status = user.identity_verified?
    end

    def track_identity_verification_pending
      return false unless success
      @verification_method = user.pending_in_person_enrollment.present? && 'IPP' ||
                             user.gpo_verification_pending_profile.present? && 'GPO' ||
                             user.identity_verified_with_biometric_comparison? && 'Biometric' || nil
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

    def extra_analytics_attributes
      {
        user_id: user.uuid,
        email: user.email_addresses.take&.email,
        account_age_in_days: account_age,
        account_confirmed_at: user.confirmed_at,
        mfa_method_counts: mfa_method_counts,
        identity_verified: verified_status,
        identity_verification_method: verification_method,
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
      }
    end
  end
end
