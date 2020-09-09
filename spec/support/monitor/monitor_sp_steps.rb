module MonitorSpSteps
  def oidc_sp_is_usajobs?
    monitor.config.oidc_sp_url.to_s.match(/usajobs\.gov/)
  end

  def visit_idp_from_oidc_sp
    visit monitor.config.oidc_sp_url
    if oidc_sp_is_usajobs?
      click_link 'Sign In', href: '/Applicant/Profile/Dashboard'
    else
      find(:css, '.sign-in-bttn').click
    end

    expect(page).to have_content(
      'is using login.gov to allow you to sign in to your account safely and securely.',
    )
    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def visit_idp_from_oidc_sp_with_ial2
    if monitor.remote?
      visit monitor.config.oidc_sp_url
      find(:css, '.details-popup summary').click
      select 'IAL 2', from: 'ial'
    else
      visit monitor.config.oidc_sp_url + '?ial=2'
    end
    find(:css, '.sign-in-bttn').click

    expect(page).to have_content(
      'is using login.gov to allow you to sign in to your account safely and securely.',
    )
    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def visit_idp_from_saml_sp
    visit monitor.config.saml_sp_url
    first(:css, '.sign-in-bttn').click

    expect(page).to have_content(
      'is using login.gov to allow you to sign in to your account safely and securely.',
    )
    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def log_out_from_oidc_sp
    return unless oidc_sp_is_usajobs?

    within('.usajobs-home__title') do
      click_link 'Sign Out'
    end

    return unless monitor.remote?
    expect(current_url).to match(%r{https://login.(uat.)?usajobs.gov/externalloggedout})
  end

  def log_out_from_saml_sp
    return unless monitor.remote?

    click_on 'Log out'
    expect(current_url).to match monitor.config.saml_sp_url
  end
end
