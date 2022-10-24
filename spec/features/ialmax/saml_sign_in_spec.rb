require 'rails_helper'

feature 'SAML IALMAX sign in' do
  include SamlAuthHelper

  context 'with an ial2 SP' do
    context 'with an ial1 user' do
      scenario 'piv sign in' do
        user = user_with_piv_cac
        visit_idp_from_saml_sp_with_ialmax
        signin_with_piv(user)
        click_submit_default
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.attribute_value_for(:ial)).to eq(
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        )
        expect { xmldoc.attribute_value_for(:ssn) }.to raise_exception

        sp_return_logs = SpReturnLog.where(user_id: user.id)
        expect(sp_return_logs.count).to eq(1)
        expect(sp_return_logs.first.ial).to eq(1)
      end

      scenario 'password sign in' do
        user = create(:user, :signed_up)
        visit_idp_from_saml_sp_with_ialmax
        sign_in_live_with_2fa(user)
        click_submit_default
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.attribute_value_for(:ial)).to eq(
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        )
        expect { xmldoc.attribute_value_for(:ssn) }.to raise_exception

        sp_return_logs = SpReturnLog.where(user_id: user.id)
        expect(sp_return_logs.count).to eq(1)
        expect(sp_return_logs.first.ial).to eq(1)
      end
    end

    context 'with an ial2 user' do
      scenario 'piv sign in' do
        pii = { phone: '+12025555555', ssn: '111111111' }
        user = create(:profile, :active, :verified, pii: pii).user
        user.piv_cac_configurations.create(x509_dn_uuid: 'helloworld', name: 'My PIV Card')
        visit_idp_from_saml_sp_with_ialmax
        signin_with_piv(user)
        click_submit_default
        fill_in 'user[password]', with: user.password
        click_submit_default_twice
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.attribute_value_for(:ial)).to eq(
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        )
        expect { xmldoc.attribute_value_for(:ssn) }.not_to raise_exception
        expect(xmldoc.attribute_value_for(:ssn)).to eq('111111111')

        sp_return_logs = SpReturnLog.where(user_id: user.id)
        expect(sp_return_logs.count).to eq(1)
        expect(sp_return_logs.first.ial).to eq(2)
      end

      scenario 'password sign in' do
        pii = { phone: '+12025555555', ssn: '111111111' }
        user = create(:profile, :active, :verified, pii: pii).user
        visit_idp_from_saml_sp_with_ialmax
        sign_in_live_with_2fa(user)
        click_submit_default
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.attribute_value_for(:ial)).to eq(
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        )
        expect { xmldoc.attribute_value_for(:ssn) }.not_to raise_exception
        expect(xmldoc.attribute_value_for(:ssn)).to eq('111111111')

        sp_return_logs = SpReturnLog.where(user_id: user.id)
        expect(sp_return_logs.count).to eq(1)
        expect(sp_return_logs.first.ial).to eq(2)
      end
    end

    context 'with an inactive profile user' do
      scenario 'piv sign in' do
        user = create(:profile, :active, :verified).user
        user.profiles.first.update!(
          active: false,
          deactivation_reason: :verification_cancelled,
        )
        user.piv_cac_configurations.create(x509_dn_uuid: 'helloworld', name: 'My PIV Card')
        visit_idp_from_saml_sp_with_ialmax
        signin_with_piv(user)
        click_submit_default
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.attribute_value_for(:ial)).to eq(
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        )
        expect { xmldoc.attribute_value_for(:ssn) }.to raise_exception

        sp_return_logs = SpReturnLog.where(user_id: user.id)
        expect(sp_return_logs.count).to eq(1)
        expect(sp_return_logs.first.ial).to eq(1)
      end

      scenario 'password sign in' do
        user = create(:profile, :active, :verified).user
        user.profiles.first.update!(
          active: false,
          deactivation_reason: :verification_cancelled,
        )
        visit_idp_from_saml_sp_with_ialmax
        sign_in_live_with_2fa(user)
        click_submit_default
        click_agree_and_continue
        click_submit_default

        xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
        expect(xmldoc.attribute_value_for(:ial)).to eq(
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        )
        expect { xmldoc.attribute_value_for(:ssn) }.to raise_exception

        sp_return_logs = SpReturnLog.where(user_id: user.id)
        expect(sp_return_logs.count).to eq(1)
        expect(sp_return_logs.first.ial).to eq(1)
      end
    end
  end

  context 'with an ial1 SP' do
    before do
      ServiceProvider.
        find_by(issuer: 'saml_sp_ial2').
        update!(ial: 1)
    end

    scenario 'returns an ial1 responses even with an ial2 user' do
      pii = { phone: '+12025555555', ssn: '111111111' }
      user = create(:profile, :active, :verified, pii: pii).user
      visit_idp_from_saml_sp_with_ialmax
      sign_in_live_with_2fa(user)
      click_submit_default
      click_agree_and_continue
      click_submit_default

      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
      expect(xmldoc.attribute_value_for(:ial)).to eq(
        Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      )
      expect { xmldoc.attribute_value_for(:ssn) }.to raise_exception

      sp_return_logs = SpReturnLog.where(user_id: user.id)
      expect(sp_return_logs.count).to eq(1)
      expect(sp_return_logs.first.ial).to eq(1)
    end
  end
end
