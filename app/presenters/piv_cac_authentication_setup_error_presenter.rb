class PivCacAuthenticationSetupErrorPresenter < PivCacAuthenticationSetupBasePresenter
  attr_accessor :error

  def initialize(error:)
    @error = error
  end

  def may_select_another_certificate?
    error.start_with?('certificate.') && error != 'certificate.none' ||
      error == 'token.invalid' || error == 'piv_cac.already_associated'
  end

  def title
    t("titles.piv_cac_setup.#{error}")
  end

  def heading
    t("headings.piv_cac_setup.#{error}")
  end

  def description
    t("forms.piv_cac_setup.#{error}_html")
  end
end
