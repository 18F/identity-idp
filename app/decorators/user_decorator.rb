include ActionView::Helpers::DateHelper

UserDecorator = Struct.new(:user) do
  def lockout_time_remaining
    (Devise.allowed_otp_drift_seconds - (Time.zone.now - user.second_factor_locked_at)).to_i
  end

  def lockout_time_remaining_in_words
    distance_of_time_in_words(
      Time.zone.now, Time.zone.now + lockout_time_remaining, true, highest_measures: 2)
  end

  def confirmation_period_expired_error
    I18n.t('errors.messages.confirmation_period_expired', period: confirmation_period)
  end

  def confirmation_period
    distance_of_time_in_words(
      Time.zone.now, Time.zone.now + Devise.confirm_within, true, accumulate_on: :hours)
  end

  def first_sentence_for_confirmation_email
    if user.reset_requested_at
      'Your Upaya account has been reset by a tech support representative. ' \
      'In order to continue, you must confirm your email address.'
    else
      "To finish #{user.confirmed_at ? 'updating' : 'creating'} your " \
      'Upaya Account, you must confirm your email address.'
    end
  end

  def mobile_change_requested?
    user.unconfirmed_mobile.present? && user.mobile.present?
  end

  def may_bypass_two_factor_setup?(session = {})
    omniauthed?(session) || user.two_factor_enabled?
  end

  def mobile_already_taken?
    user.errors.include?(:mobile) && user.errors[:mobile] == [I18n.t('errors.messages.taken')]
  end

  def email_already_taken?
    user.errors.include?(:email) && user.errors[:email].uniq == [I18n.t('errors.messages.taken')]
  end

  private

  def omniauthed?(session)
    return false if session[:omniauthed] != true

    session.delete(:omniauthed)
  end
end
