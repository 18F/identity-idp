require 'rails_helper'

RSpec.feature 'Sign in with multiple vectors of trust' do
  include SamlAuthHelper
  include OidcAuthHelper
  include IdvHelper
  include DocAuthHelper

  context 'with OIDC' do
    context 'facial match and non-facial match proofing is acceptable' do
      scenario 'identity proofing is not required if user is proofed with facial match' do
        user = create(:user, :proofed_with_selfie)

        visit_idp_from_oidc_sp_with_vtr(vtr: ['C1.C2.P1.Pb', 'C1.C2.P1'])
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue

        user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

        expect(user_info[:given_name]).to be_present
        expect(user_info[:vot]).to eq('C1.C2.P1.Pb')
      end

      scenario 'identity proofing is not required if user is proofed without facial match' do
        user = create(:user, :proofed)

        visit_idp_from_oidc_sp_with_vtr(vtr: ['C1.C2.P1.Pb', 'C1.C2.P1'])
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue

        user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

        expect(user_info[:given_name]).to be_present
        expect(user_info[:vot]).to eq('C1.C2.P1')
      end

      scenario 'identity proofing with facial match is required if user is not proofed', :js do
        user = create(:user, :fully_registered)

        visit_idp_from_oidc_sp_with_vtr(vtr: ['C1.C2.P1.Pb', 'C1.C2.P1'])
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(idv_welcome_path)
        complete_all_doc_auth_steps_before_password_step(with_selfie: true)
        fill_in 'Password', with: user.password
        click_continue
        acknowledge_and_confirm_personal_key

        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue

        user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

        expect(user_info[:given_name]).to be_present
        expect(user_info[:vot]).to eq('C1.C2.P1.Pb')
      end
    end

    context 'proofing or no proofing is acceptable (IALMAX)' do
      scenario 'identity proofing is not required if the user is not proofed' do
        user = create(:user, :fully_registered)

        visit_idp_from_oidc_sp_with_vtr(
          vtr: ['C1.C2.P1', 'C1.C2'],
          scope: 'openid email profile:name',
        )
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue

        user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

        expect(user_info[:given_name]).to_not be_present
        expect(user_info[:vot]).to eq('C1.C2')
      end

      scenario 'attributes are shared if the user is proofed' do
        user = create(:user, :proofed)

        visit_idp_from_oidc_sp_with_vtr(
          vtr: ['C1.C2.P1', 'C1.C2'],
          scope: 'openid email profile:name',
        )
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue

        user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

        expect(user_info[:given_name]).to be_present
        expect(user_info[:vot]).to eq('C1.C2.P1')
      end

      scenario 'identity proofing is not required if proofed user resets password' do
        user = create(:user, :proofed)

        visit_idp_from_oidc_sp_with_vtr(
          vtr: ['C1.C2.P1', 'C1.C2'],
          scope: 'openid email profile:name',
        )
        trigger_reset_password_and_click_email_link(user.email)
        reset_password(user, 'new even better password')
        user.password = 'new even better password'
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue

        user_info = OpenidConnectUserInfoPresenter.new(user.identities.last).user_info

        expect(user_info[:given_name]).to_not be_present
        expect(user_info[:vot]).to eq('C1.C2')
      end
    end
  end

  context 'with SAML' do
    before do
      if javascript_enabled?
        service_provider = ServiceProvider.find_by(issuer: sp1_issuer)
        acs_url = URI.parse(service_provider.acs_url)
        acs_url.host = page.server.host
        acs_url.port = page.server.port
        service_provider.update(acs_url: acs_url.to_s)
      end
    end

    context 'facial match and non-facial match proofing is acceptable' do
      scenario 'identity proofing is not required if user is proofed with facial match' do
        user = create(:user, :proofed_with_selfie)

        visit_saml_authn_request_url(
          overrides: { issuer: sp1_issuer, authn_context: ['C1.C2.P1.Pb', 'C1.C2.P1'] },
        )
        sign_in_live_with_2fa(user)

        click_submit_default
        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.assertion_statement_node.content).to eq('C1.C2.P1.Pb')
        expect(xmldoc.attribute_node_for('vot').content).to eq('C1.C2.P1.Pb')

        first_name = xmldoc.attribute_node_for('first_name').content
        expect(first_name).to_not be_blank
      end

      scenario 'identity proofing is not required if user is proofed without facial match' do
        user = create(:user, :proofed)

        visit_saml_authn_request_url(
          overrides: { issuer: sp1_issuer, authn_context: ['C1.C2.P1.Pb', 'C1.C2.P1'] },
        )
        sign_in_live_with_2fa(user)

        click_submit_default
        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.assertion_statement_node.content).to eq('C1.C2.P1')
        expect(xmldoc.attribute_node_for('vot').content).to eq('C1.C2.P1')

        first_name = xmldoc.attribute_node_for('first_name').content
        expect(first_name).to_not be_blank
      end

      scenario 'identity proofing with facial match is required if user is not proofed', :js do
        user = create(:user, :fully_registered)

        visit_saml_authn_request_url(
          overrides: { issuer: sp1_issuer, authn_context: ['C1.C2.P1.Pb', 'C1.C2.P1'] },
        )
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(idv_welcome_path)
        complete_all_doc_auth_steps_before_password_step(with_selfie: true)
        fill_in 'Password', with: user.password
        click_continue
        acknowledge_and_confirm_personal_key

        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.assertion_statement_node.content).to eq('C1.C2.P1.Pb')
        expect(xmldoc.attribute_node_for('vot').content).to eq('C1.C2.P1.Pb')

        first_name = xmldoc.attribute_node_for('first_name').content
        expect(first_name).to_not be_blank
      end
    end

    context 'proofing or no proofing is acceptable (IALMAX)' do
      scenario 'identity proofing is not required if the user is not proofed' do
        user = create(:user, :fully_registered)

        visit_saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: [
              'C1.C2.P1',
              'C1.C2',
              "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name",
            ],
          },
        )
        sign_in_live_with_2fa(user)

        click_submit_default
        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.assertion_statement_node.content).to eq('C1.C2')
        expect(xmldoc.attribute_node_for('vot').content).to eq('C1.C2')

        first_name_node = xmldoc.attribute_node_for('first_name')
        expect(first_name_node).to be_nil
      end

      scenario 'attributes are shared if the user is proofed' do
        user = create(:user, :proofed)

        visit_saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: [
              'C1.C2.P1',
              'C1.C2',
              "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name",
            ],
          },
        )
        sign_in_live_with_2fa(user)

        click_submit_default
        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.assertion_statement_node.content).to eq('C1.C2.P1')
        expect(xmldoc.attribute_node_for('vot').content).to eq('C1.C2.P1')

        first_name = xmldoc.attribute_node_for('first_name').content
        expect(first_name).to_not be_blank
      end

      scenario 'identity proofing is not required if proofed user resets password' do
        user = create(:user, :proofed)

        visit_saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: [
              'C1.C2.P1',
              'C1.C2',
              "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name",
            ],
          },
        )
        trigger_reset_password_and_click_email_link(user.email)
        reset_password(user, 'new even better password')
        user.password = 'new even better password'
        sign_in_live_with_2fa(user)

        click_submit_default
        expect(page).to have_current_path(sign_up_completed_path)
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.assertion_statement_node.content).to eq('C1.C2')
        expect(xmldoc.attribute_node_for('vot').content).to eq('C1.C2')

        first_name_node = xmldoc.attribute_node_for('first_name')
        expect(first_name_node).to be_nil
      end
    end
  end
end
