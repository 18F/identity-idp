module MonitorSpSteps
  def oidc_sp_is_usajobs?
    monitor.config.oidc_sp_url.to_s.match(/usajobs\.gov/)
  end

  def visit_idp_from_oidc_sp
    visit monitor.config.oidc_sp_url
    if oidc_sp_is_usajobs?
      click_on 'Sign In'
    else
      find(:css, '.sign-in-bttn').click
    end

    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def visit_idp_from_oidc_sp_with_ial2
    visit monitor.config.oidc_sp_url + '?ial=2'
    find(:css, '.sign-in-bttn').click

    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def visit_idp_from_saml_sp
    visit monitor.config.saml_sp_url
    first(:css, '.sign-in-bttn').click

    expect(current_url).to match(%r{https://(idp|secure)\..*\.gov}) if monitor.remote?
  end

  def log_out_from_oidc_sp
    if oidc_sp_is_usajobs?
      within('.usajobs-home__title') do
        click_link 'Sign Out'
      end
      expect(current_url).to match(%r{https://login.(uat.)?usajobs.gov/externalloggedout}) if monitor.remote?
    end
  end

  def log_out_from_saml_sp
    if monitor.remote?
      click_on 'Log out'
      expect(current_url).to match monitor.config.saml_sp_url
    end
  end
end
