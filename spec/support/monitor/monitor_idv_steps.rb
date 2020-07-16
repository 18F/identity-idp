module MonitorIdvSteps
  def verify_identity_with_doc_auth
    allow(Figaro.env).to receive(:doc_auth_vendor).and_return('mock') if monitor.local?

    expect(page).to have_content 'You will also need'
    click_on 'Create an account'
    create_new_account_with_sms
    expect(page).to have_current_path('/verify/doc_auth/welcome')

    check 'ial2_consent_given', visible: :all, allow_label_click: true
    expect(page).to have_button('Continue', disabled: :all)

    click_on 'Continue'
    expect(page).to have_current_path('/verify/doc_auth/upload')

    click_on 'Upload from your computer'
    expect(page).to have_current_path('/verify/doc_auth/front_image')

    click_doc_auth_fallback_link

    attach_file 'doc_auth_image', File.expand_path('spec/fixtures/ial2_test_credential.yml')
    click_on 'Continue'
    expect(page).to have_current_path('/verify/doc_auth/back_image')

    click_doc_auth_fallback_link

    attach_file 'doc_auth_image', File.expand_path('spec/fixtures/ial2_test_credential.yml')
    click_on 'Continue'
    expect(page).to have_current_path('/verify/doc_auth/ssn')

    fill_in 'doc_auth_ssn', with: format('%09d', SecureRandom.random_number(1e9))
    click_on 'Continue'
    expect(page).to have_current_path('/verify/doc_auth/verify')

    click_on 'Continue'
    expect(page).to have_current_path('/verify/doc_auth/doc_success')

    click_on 'Continue'
    expect(page).to have_current_path('/verify/phone')

    click_on 'Continue'
    expect(page).to have_current_path('/verify/review')

    fill_in 'Password', with: monitor.config.login_gov_sign_in_password
    click_on 'Continue'
    expect(page).to have_current_path('/verify/confirmations')

    extra_characters_get_ignored = 'abc123qwerty'
    code_words = []
    page.all(:css, '[data-personal-key]').map do |node|
      code_words << node.text
    end
    click_on 'Continue', class: 'personal-key-continue'

    # Need to figure out what feature flag enables the personal key code locally
    return unless monitor.remote?

    personal_key = code_words.join('-').downcase

    fill_in 'personal_key', with: (personal_key + extra_characters_get_ignored), disabled: :all
    click_on 'Continue', class: 'personal-key-confirm'

    # HTML fallback for failed personal key
    fill_in 'personal_key', with: personal_key, disabled: :all
    click_on 'Continue', class: 'personal-key-confirm'
  end

  def click_doc_auth_fallback_link
    return if page.has_css?('#doc_auth_image', visible: true)

    fallback_link = page.find('#acuant-fallback-link', wait: 7)
    fallback_link&.click
  end
end
