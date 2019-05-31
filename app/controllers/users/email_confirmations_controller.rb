# :reek:RepeatedConditional
module Users
  class EmailConfirmationsController < ApplicationController
    def create
      if email_address&.confirmed_at
        process_already_confirmed_user
      else
        validate_token
      end
    end

    private

    def validate_token
      result = AddEmailConfirmTokenValidator.new(email_address).submit
      analytics.track_event(Analytics::ADD_EMAIL_CONFIRMATION, result.to_h)
      if result.success?
        process_successful_confirmation(email_address)
      else
        process_unsuccessful_confirmation
      end
    end

    def email_address
      @email_address ||= EmailAddress.find_by(confirmation_token: params[:confirmation_token])
    end

    def process_successful_confirmation(email_address)
      confirm_and_notify_user(email_address)
      if current_user
        flash[:success] = t('devise.confirmations.confirmed')
        redirect_to account_url
      else
        flash[:success] = t('devise.confirmations.confirmed_but_sign_in')
        redirect_to root_url
      end
    end

    def confirm_and_notify_user(email_address)
      email_address.update!(confirmed_at: Time.zone.now)
      UserMailer.email_added(email_address.email).deliver_later
    end

    def process_unsuccessful_confirmation
      redirect_to root_url
    end

    def unsuccessful_confirmation_error
      if @user.confirmation_period_expired?
        @user.decorate.confirmation_period_expired_error
      else
        t('errors.messages.confirmation_invalid_token')
      end
    end

    def process_already_confirmed_user
      flash[:error] = message_for_already_confirmed_user
      redirect_to current_user ? account_url : root_url
    end

    def message_for_already_confirmed_user
      if current_user
        if current_user.id == email_address.user.id
          t('devise.confirmations.already_confirmed', action: nil)
        else
          t('devise.confirmations.confirmed_but_remove_from_other_account')
        end
      else
        action_text = t('devise.confirmations.sign_in')
        t('devise.confirmations.already_confirmed', action: action_text)
      end
    end
  end
end
