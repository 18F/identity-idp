class AccountsController < ApplicationController
  before_action :confirm_two_factor_authenticated

  layout 'card_wide'

  def show
    analytics.track_event(Analytics::ACCOUNT_VISIT)
    cacher = Pii::Cacher.new(current_user, user_session)

    @view_model = AccountShow.new(
      decrypted_pii: cacher.fetch,
      personal_key: flash[:personal_key],
      decorated_user: current_user.decorate,
      message: mfas_successfully_enabled_message,
    )
  end

  def mfas_successfully_enabled_message
    if session[:signed_up]
      session.delete(:signed_up)
      build_mfa_message(MfasEnabledForUser.call(current_user))
    end
  end

  private

  def build_mfa_message(methds)
    translated = []
    methds.each { |val| translated.push(t("two_factor_authentication.devices.#{val}")) }
    t('two_factor_authentication.mfa_factors_enabled', devices: translated.join(' and '))
  end
end
