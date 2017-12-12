shared_examples 'csrf error when asking for new personal key' do |sp|
  it 'redirects to sign in page', email: true do
    visit_idp_from_sp_with_loa1(sp)
    register_user
    allow_any_instance_of(Users::PersonalKeysController).
      to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)
    click_on t('users.personal_key.get_another')

    expect(current_path).to eq new_user_session_path
    expect(page).to have_content t('errors.invalid_authenticity_token')
  end
end

shared_examples 'csrf error when acknowledging personal key' do |sp|
  it 'redirects to sign in page', email: true do
    visit_idp_from_sp_with_loa1(sp)
    register_user
    allow_any_instance_of(SignUp::PersonalKeysController).
      to receive(:update).and_raise(ActionController::InvalidAuthenticityToken)
    click_acknowledge_personal_key

    expect(current_path).to eq new_user_session_path
    expect(page).to have_content t('errors.invalid_authenticity_token')
  end
end
