shared_examples 'ial2 consent with js' do
  it 'shows the notice if the user clicks continue without giving consent' do
    expect(page).to have_button('Continue')
    click_continue

    expect(page).to have_current_path(idv_doc_auth_welcome_step)
    expect(page).to have_content(t('errors.doc_auth.consent_form'))
  end

  it 'allows the user to continue after checking the checkbox' do
    find('span[class="indicator"]').set(true)
    expect(page).to have_button('Continue')
    click_continue

    expect_doc_auth_upload_step
  end
end

shared_examples 'ial2 consent without js' do
  it 'renders error when user continues without checking the checkbox' do
    click_continue

    expect_doc_auth_first_step

    expect(page).to have_content(t('errors.doc_auth.consent_form'))
  end

  it 'allows the user to continue after checking the checkbox' do
    find('input[name="ial2_consent_given"]').set(true)
    click_continue

    expect_doc_auth_upload_step
  end
end
