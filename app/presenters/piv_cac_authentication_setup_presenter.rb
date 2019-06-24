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

  def steps_visible?
    SignUpProgressPolicy.new(
      user, fully_authenticated
    ).sign_up_progress_visible?
  end

  private

  def no_factors_enabled?
    MfaPolicy.new(user).no_factors_enabled?
  end
end
