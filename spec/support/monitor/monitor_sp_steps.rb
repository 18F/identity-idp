module MonitorSpSteps
  def visit_idp_from_oidc_sp
    visit monitor.config.oidc_sp_url
    find(:css, '.sign-in-bttn').click

    expect(page).to have_content(
      'is using Login.gov to allow you to sign in to your account safely and securely.',
    )
    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def visit_idp_from_oidc_sp_with_ial2
    visit monitor.config.oidc_sp_url + '?ial=2'
    find(:css, '.sign-in-bttn').click

    expect(page).to have_content(
      'is using Login.gov to allow you to sign in to your account safely and securely.',
    )
    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def visit_idp_from_saml_sp
    visit monitor.config.saml_sp_url
    first(:css, '.sign-in-bttn').click

    expect(page).to have_content(
      'is using Login.gov to allow you to sign in to your account safely and securely.',
    )
    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def log_out_from_oidc_sp
    return unless monitor.remote?

    click_on 'Log out'
  end

  def log_out_from_saml_sp
    return unless monitor.remote?

    click_on 'Log out'
    expect(current_url).to match monitor.config.saml_sp_url
  end
end
