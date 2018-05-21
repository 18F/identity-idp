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
end
