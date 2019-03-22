class PivCacAuthenticationLoginPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  attr_reader :form

  def initialize(form)
    @form = form
  end

  def piv_cac_capture_text
    t('forms.piv_cac_login.submit')
  end

  def piv_cac_service_link
    login_present_piv_cac_url
  end

  def title
    t('titles.piv_cac_login.new')
  end

  def heading
    t('headings.piv_cac_login.new')
  end
end
