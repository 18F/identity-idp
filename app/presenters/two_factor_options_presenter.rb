class TwoFactorOptionsPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :current_user, :service_provider

  def initialize(current_user, sp)
    @current_user = current_user
    @service_provider = sp
  end

  def title
    t('titles.two_factor_setup')
  end

  def heading
    t('devise.two_factor_authentication.two_factor_choice')
  end

  def info
    t('devise.two_factor_authentication.two_factor_choice_intro')
  end

  def label
    t('forms.two_factor_choice.legend') + ':'
  end

  def options
    available_2fa_types.map do |type|
      type = :auth_app if type == :totp
      OpenStruct.new(
        type: type.to_s,
        label: t("devise.two_factor_authentication.two_factor_choice_options.#{type}"),
        info: t("devise.two_factor_authentication.two_factor_choice_options.#{type}_info"),
        selected: type == :sms
      )
    end
  end

  private

  def available_2fa_types
    current_user.two_factor_configurable_method_configurations.map(&:method) | piv_cac_if_available
  end

  def piv_cac_if_available
    return [] if current_user.two_factor_enabled?(%i[piv_cac])
    return %i[piv_cac] if current_user.two_factor_configurable?(%i[piv_cac]) ||
                          service_provider&.piv_cac_available?
    []
  end
end
