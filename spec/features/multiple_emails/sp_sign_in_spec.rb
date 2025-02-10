require 'rails_helper'

RSpec.feature 'signing into an SP with multiple emails enabled' do
  include SamlAuthHelper
  include OidcAuthHelper

  context 'with the email scope' do
    scenario 'signing in with OIDC sends the email address used to sign in' do
      user = create(:user, :fully_registered, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      expect(emails.count).to eq(2)

      emails.each do |email|
        visit_idp_from_oidc_sp(scope: 'openid email')
        signin(email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default
        click_agree_and_continue if current_path == sign_up_completed_path
        expect(oidc_decoded_id_token[:email]).to eq(emails.first)
        expect(oidc_decoded_id_token[:all_emails]).to be_nil

        Capybara.reset_session!
      end
    end

    scenario 'signing in with OIDC and selecting an alternative email address at first sign in' do
      user = create(:user, :fully_registered, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      visit_idp_from_oidc_sp(scope: 'openid email')
      signin(emails.first, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_link(t('help_text.requested_attributes.change_email_link'))

      choose emails.second

      click_button(t('help_text.requested_attributes.select_email_link'))

      expect(page).to have_current_path(sign_up_completed_path)
      click_agree_and_continue
      expect(oidc_decoded_id_token[:email]).to eq(emails.second)
    end

    scenario 'signing in with OIDC after deleting email linked to identity' do
      user = create(:user, :fully_registered)
      email1 = create(:email_address, user:, email: 'email1@example.com')
      email2 = create(:email_address, user:, email: 'email2@example.com')

      # Link identity with email
      visit_idp_from_oidc_sp(scope: 'openid email')
      signin(email1.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_link(t('help_text.requested_attributes.change_email_link'))
      choose email2.email
      click_button(t('help_text.requested_attributes.select_email_link'))
      expect(page).to have_current_path(sign_up_completed_path)
      click_agree_and_continue
      click_submit_default

      # Delete email from account
      visit manage_email_confirm_delete_url(id: email2.id)
      click_button t('forms.email.buttons.delete')

      # Sign in again to partner application
      visit_idp_from_oidc_sp(scope: 'openid email')

      expect(oidc_decoded_id_token[:email]).to eq(email1.email)
    end

    scenario 'signing in with SAML sends the email address used to sign in' do
      user = create(:user, :fully_registered, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      expect(emails.count).to eq(2)

      emails.each do |email|
        visit authn_request
        signin(email, user.password)
        fill_in_code_with_last_phone_otp
        click_submit_default_twice
        click_agree_and_continue if current_path == sign_up_completed_path
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        email_from_saml_response = xmldoc.attribute_value_for('email')
        expect(email_from_saml_response).to eq(emails.first)

        Capybara.reset_session!
      end
    end

    scenario 'signing in with SAML and selecting an alternative email address at first sign in' do
      user = create(:user, :fully_registered, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      visit authn_request
      signin(emails.first, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default_twice

      click_link(t('help_text.requested_attributes.change_email_link'))
      choose emails.second
      click_button(t('help_text.requested_attributes.select_email_link'))

      expect(page).to have_current_path(sign_up_completed_path)

      click_agree_and_continue
      click_submit_default

      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
      email_from_saml_response = xmldoc.attribute_value_for('email')
      expect(email_from_saml_response).to eq(emails.second)
    end

    scenario 'signing in with SAML after deleting email linked to identity' do
      user = create(:user, :fully_registered)
      email1 = create(:email_address, user:, email: 'email1@example.com')
      email2 = create(:email_address, user:, email: 'email2@example.com')

      # Link identity with email
      visit authn_request
      signin(email1.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default_twice
      click_link(t('help_text.requested_attributes.change_email_link'))
      choose email2.email
      click_button(t('help_text.requested_attributes.select_email_link'))
      expect(page).to have_current_path(sign_up_completed_path)
      click_agree_and_continue
      click_submit_default

      # Delete email from account
      visit manage_email_confirm_delete_url(id: email2.id)
      click_button t('forms.email.buttons.delete')

      # Sign in again to partner application
      visit authn_request

      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
      email_from_saml_response = xmldoc.attribute_value_for('email')
      expect(email_from_saml_response).to eq(email1.email)
    end
  end

  context 'with the all_emails scope' do
    scenario 'signing in with OIDC sends all emails' do
      user = create(:user, :fully_registered, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      expect(emails.count).to eq(2)

      visit_idp_from_oidc_sp(scope: 'openid all_emails')
      signin(emails.first, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      expect(oidc_decoded_id_token[:all_emails]).to match_array(emails)
    end

    scenario 'signing in with SAML sends all emails' do
      user = create(:user, :fully_registered, :with_multiple_emails)
      emails = user.reload.email_addresses.map(&:email)

      expect(emails.count).to eq(2)

      settings = saml_settings(
        overrides: {
          authn_context: [
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}all_emails",
          ],
        },
      )
      visit authn_request(settings)
      signin(emails.first, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default_twice
      click_agree_and_continue
      click_submit_default

      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

      emails_from_saml_response = xmldoc.attribute_node_for('all_emails').children.map(&:text)
      expect(emails_from_saml_response).to match_array(emails)
    end
  end

  def visit_idp_from_oidc_sp(scope:)
    visit openid_connect_authorize_path(
      client_id: 'urn:gov:gsa:openidconnect:sp:server',
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: scope,
      redirect_uri: 'http://localhost:7654/auth/result',
      state: SecureRandom.hex,
      prompt: 'select_account',
      nonce: SecureRandom.hex,
    )
  end
end
