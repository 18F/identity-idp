shared_examples 'ial2 consent with js' do
  it 'does not allow the user to continue without checking the checkbox' do
    expect(page).to have_button('Continue', disabled: true)
  end

  it 'allows the user to continue after checking the checkbox' do
    find('span[class="indicator"]').set(true)
    expect(page).to have_button('Continue', disabled: false)
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
