shared_examples 'ial2 consent' do
  it 'shows the notice if the user clicks continue without giving consent' do
    click_continue

    expect_doc_auth_first_step
    expect(page).to have_content(t('errors.doc_auth.consent_form'))
  end

  it 'allows the user to continue after checking the checkbox' do
    check :ial2_consent_given
    click_continue

    expect_doc_auth_upload_step
  end
end
