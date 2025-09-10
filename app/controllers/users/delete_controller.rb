# frozen_string_literal: true

module Users
  class DeleteController < ApplicationController
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_current_password, only: [:delete]
    before_action :confirm_recently_authenticated_2fa

    def show
      analytics.account_delete_visited
    end

    def delete
      send_push_notifications
      notify_user_via_email_of_deletion
      notify_user_via_sms_of_deletion
      analytics.account_delete_submitted(success: true)
      measure_one_account_self_service_if_applicable
      attempts_api_tracker.logged_in_account_purged(success: true)
      delete_user
      sign_out
      flash[:success] = t('devise.registrations.destroyed')
      redirect_to root_url
    end

    private

    def delete_user
      ActiveRecord::Base.transaction do
        DeletedUser.create_from_user(current_user)
        current_user.destroy!
      end
    end

    def confirm_current_password
      return if valid_password?

      flash.now[:error] = t('idv.errors.incorrect_password')
      analytics.account_delete_submitted(success: false)
      attempts_api_tracker.logged_in_account_purged(success: false)
      render :show
    end

    def valid_password?
      current_user.valid_password?(password)
    end

    def password
      params.fetch(:user, {})[:password].presence
    end

    def send_push_notifications
      event = PushNotification::AccountPurgedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
    end

    # rubocop:disable IdentityIdp/MailLaterLinter
    def notify_user_via_email_of_deletion
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: current_user, email_address: email_address)
          .account_delete_completed.deliver_now
      end
    end
    # rubocop:enable IdentityIdp/MailLaterLinter

    def notify_user_via_sms_of_deletion
      phone_configurations = current_user.phone_configurations
      phone_configurations.each do |configuration|
        next unless configuration.capabilities.supports_sms?
        Telephony.send_account_deleted_notice(
          to: configuration.phone,
          country_code: Phonelib.parse(configuration.phone).country,
        )
      end
    end

    def measure_one_account_self_service_if_applicable
      return unless user_has_ial2_facial_match_profile?
      set = DuplicateProfileSet.find_by_profile(profile_id: current_user&.active_profile)
      return unless set

      analytics.one_account_self_service(
        source: :account_management_delete,
        service_provider: set.service_provider,
        associated_profiles_count: set.profile_ids.exclude?(current_user.active_profile.id).count,
        dupe_profile_set_id: set.id,
      )
    end
  end
end
