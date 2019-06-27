class PivCacAuthenticationSetupBasePresenter < SetupPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  attr_reader :form, :user, :fully_authenticated

  def initialize(current_user, user_fully_authenticated, form)
    @current_user = current_user
    @user_fully_authenticated = user_fully_authenticated
    @form = form
  end

  def piv_cac_capture_text
    t('forms.piv_cac_setup.submit')
  end

  def piv_cac_service_link
    redirect_to_piv_cac_service_url
  end
end
