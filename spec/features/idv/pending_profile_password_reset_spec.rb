require 'rails_helper'

RSpec.describe 'Resetting password with a pending profile' do
  include OidcAuthHelper

  let(:sp_name) { 'Test SP' }
  before do
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name)
      .and_return(sp_name)
  end

  scenario 'while GPO pending requires the user to reproof' do
    user = create(:user, :with_phone, :with_pending_gpo_profile)

    visit_idp_from_ial2_oidc_sp
    fill_forgot_password_form(user)
    click_reset_password_link_from_email

    new_password = '$alty pickles'
    fill_in t('forms.passwords.edit.labels.password'), with: new_password
    fill_in t('components.password_confirmation.confirm_label'),
            with: new_password
    click_button t('forms.passwords.edit.buttons.submit')

    user.password = new_password
    sign_in_live_with_2fa(user)

    expect(page).to have_content t('doc_auth.headings.welcome', sp_name: sp_name)
    expect(page).to have_current_path(idv_welcome_path)

    expect(user.reload.active_or_pending_profile).to be_nil
  end

  scenario 'while in-person pending prompts user for personal key' do
    user = create(:user, :with_phone, :with_pending_in_person_enrollment)

    visit_idp_from_ial2_oidc_sp
    fill_forgot_password_form(user)
    click_reset_password_link_from_email

    new_password = '$alty pickles'
    fill_in t('forms.passwords.edit.labels.password'), with: new_password
    fill_in t('components.password_confirmation.confirm_label'),
            with: new_password
    fill_in t('components.password_confirmation.confirm_label'),
            with: new_password
    click_button t('forms.passwords.edit.buttons.submit')

    user.password = new_password
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(reactivate_account_path)

    expect(user.reload.active_or_pending_profile).to be_nil
  end

  scenario 'while fraud pending' do
    user = create(:user, :with_phone, :fraud_review_pending)

    visit_idp_from_ial2_oidc_sp
    fill_forgot_password_form(user)
    click_reset_password_link_from_email

    new_password = '$alty pickles'
    fill_in t('forms.passwords.edit.labels.password'), with: new_password
    fill_in t('components.password_confirmation.confirm_label'),
            with: new_password
    click_button t('forms.passwords.edit.buttons.submit')

    user.password = new_password
    sign_in_live_with_2fa(user)

    expect(page).to have_content(t('doc_auth.headings.welcome', sp_name: sp_name))
    expect(page).to have_current_path(idv_welcome_path)

    expect(user.reload.active_or_pending_profile).to be_nil
  end
end
