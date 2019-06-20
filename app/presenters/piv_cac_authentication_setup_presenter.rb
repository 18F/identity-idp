class PivCacAuthenticationSetupPresenter < PivCacAuthenticationSetupBasePresenter
  def title
    t('titles.piv_cac_setup.new')
  end

  def heading
    t('headings.piv_cac_setup.new')
  end

  def description
    t('forms.piv_cac_setup.piv_cac_intro_html')
  end

  def step
    no_factors_enabled? ? '3' : '4'
  end

  def no_factors_enabled?
    MfaPolicy.new(@current_user).no_factors_enabled?
  end
end
