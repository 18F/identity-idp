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
    available_2fa_managers.map(&:selection_presenter)
  end

  private

  delegate :two_factor_method_manager, to: :current_user

  def available_2fa_managers
    two_factor_method_manager.
      configurable_configuration_managers | piv_cac_if_available
  end

  def piv_cac_if_available
    piv_cac_manager = two_factor_method_manager.configuration_manager(:piv_cac)
    return [] if piv_cac_manager.enabled?
    return [piv_cac_manager] if piv_cac_manager.configurable? ||
                                service_provider&.piv_cac_available?
    []
  end
end
