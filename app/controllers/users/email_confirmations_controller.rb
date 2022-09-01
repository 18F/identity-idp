module Users
  class EmailConfirmationsController < ApplicationController
    def create
      result = email_confirmation_token_validator.submit
      analytics.add_email_confirmation(**result.to_h)
      if result.success?
        process_successful_confirmation(email_address)
      else
        process_unsuccessful_confirmation
      end
    end

    private

    def email_address
      return @email_address if defined?(@email_address)

      email_address = EmailAddress.find_with_confirmation_token(params[:confirmation_token])
      if email_address&.user&.confirmed?
        @email_address = email_address
      else
        @email_address = nil
      end
    end

    def email_confirmation_token_validator
      @email_confirmation_token_validator ||= begin
        EmailConfirmationTokenValidator.new(
          email_address,
          current_user,
        )
      end
    end

    def email_address_already_confirmed?
      email_confirmation_token_validator.email_address_already_confirmed?
    end

    def process_successful_confirmation(email_address)
      confirm_and_notify(email_address)
      if current_user
        flash[:success] = t('devise.confirmations.confirmed')
        redirect_to account_url
      else
        flash[:success] = t('devise.confirmations.confirmed_but_sign_in')
        redirect_to root_url
      end
    end

    def confirm_and_notify(email_address)
      email_address.update!(confirmed_at: Time.zone.now)
      email_address.user.confirmed_email_addresses.each do |confirmed_email_address|
        UserMailer.email_added(email_address.user, confirmed_email_address.email).
          deliver_now_or_later
      end
      notify_subscribers(email_address)
    end

    def notify_subscribers(email_address)
      user = email_address.user
      email_event = PushNotification::EmailChangedEvent.new(user: user, email: email_address.email)
      PushNotification::HttpPush.deliver(email_event)
      recovery_event = PushNotification::RecoveryInformationChangedEvent.new(user: user)
      PushNotification::HttpPush.deliver(recovery_event)
    end

    def process_unsuccessful_confirmation
      return process_already_confirmed_user if email_address_already_confirmed?
      flash[:error] = t('errors.messages.confirmation_invalid_token')
      redirect_to root_url
    end

    def process_already_confirmed_user
      flash[:error] = message_for_already_confirmed_user
      redirect_to current_user ? account_url : root_url
    end

    def message_for_already_confirmed_user
      if email_address_already_confirmed_by_current_user?
        t('devise.confirmations.already_confirmed', action: nil)
      elsif user_signed_in?
        t('devise.confirmations.confirmed_but_remove_from_other_account', app_name: APP_NAME)
      else
        action_text = t('devise.confirmations.sign_in')
        t('devise.confirmations.already_confirmed', action: action_text)
      end
    end

    def email_address_already_confirmed_by_current_user?
      user_signed_in? &&
        email_confirmation_token_validator.email_address_already_confirmed_by_user?(current_user)
    end
  end
end
