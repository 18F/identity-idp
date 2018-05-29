class PivCacAuthenticationSetupBasePresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  attr_reader :form

  def initialize(form)
    @form = form
  end

  def piv_cac_nonce
    @form.nonce
  end

  def piv_cac_capture_text
    t('forms.piv_cac_setup.submit')
  end

  def piv_cac_service_link
    PivCacService.piv_cac_service_link(piv_cac_nonce)
  end
end
