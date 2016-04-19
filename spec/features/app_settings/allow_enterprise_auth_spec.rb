# Feature Management: allow_enterprise_auth?
feature 'allow Enterprise Auth' do
  describe 'disabled' do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.add_mock(
        :saml,
        provider: 'saml',
        uid: '123',
        info: {
          email: 'rogue_saml_response@18f.gov',
          uuid: '123',
          first_name: 'first name',
          last_name: 'last name',
          groups: OmniauthCallbackPolicy::AUTHORIZED_TECH_SUPPORT_SAML_GROUP
        },
        extra: {
          raw_info: {
            emailAddress: 'rogue_saml_response@18f.gov',
            UUID: '123',
            sn: 'first name',
            givenName: 'last name',
            groups: OmniauthCallbackPolicy::AUTHORIZED_TECH_SUPPORT_SAML_GROUP
          }
        }
      )
      allow(FeatureManagement).to receive(:allow_enterprise_auth?).and_return(false)
      visit '/users/auth/saml/callback'
    end

    scenario 'valid saml response is unauthorized' do
      expect(page.status_code).to eq(401)
    end
  end

  describe 'enabled' do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.add_mock(
        :saml,
        provider: 'saml',
        uid: '123',
        info: {
          email: 'expected_saml_response@18f.gov',
          uuid: '124',
          first_name: 'first name',
          last_name: 'last name',
          groups: OmniauthCallbackPolicy::AUTHORIZED_TECH_SUPPORT_SAML_GROUP
        },
        extra: {
          raw_info: {
            emailAddress: 'expected_saml_response@18f.gov',
            UUID: '124',
            sn: 'first name',
            givenName: 'last name',
            groups: OmniauthCallbackPolicy::AUTHORIZED_TECH_SUPPORT_SAML_GROUP
          }
        }
      )
      allow(FeatureManagement).to receive(:allow_enterprise_auth?).and_return(true)
      visit '/users/auth/saml/callback'
    end

    xscenario 'valid saml response is authenticated' do
      expect(current_path).to eq('/support')
    end
  end
end
