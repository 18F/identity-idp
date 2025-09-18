require 'rails_helper'

RSpec.feature 'One Account Sign In' do
  include SessionTimeoutWarningHelper
  include ActionView::Helpers::DateHelper
  include PersonalKeyHelper
  include SamlAuthHelper
  include OidcAuthHelper
  include SpAuthHelper
  include IdvHelper
  include DocAuthHelper
  include AbTestsHelper

  let(:user) { create(:user, :fully_registered) }
  let(:service_provider) { create(:service_provider, :active, issuer: 'urn:gov:gsa:openidconnect:sp:server') }
  let(:pii_attrs) do
    {
      first_name: 'John',
      last_name: 'Doe',
      ssn: '123-45-6789',
      dob: '1980-01-01',
      address1: '123 Main St',
      city: 'Anytown',
      state: 'NY',
      zipcode: '12345'
    }
  end

  context 'with One Account Enabled for a specific SP' do
    let(:user) { create(:user, :fully_registered) }
    let(:user2) { create(:user, :fully_registered) }
    let(:issuer) { OidcAuthHelper::OIDC_ISSUER }
    let(:current_sp) { ServiceProvider.find_by(issuer: issuer) }
    let(:ssn_fingerprint) { 'aaa' }  
    let!(:profile1) do
      create(
        :profile, 
        :active, 
        :facial_match_proof, 
        :with_pii, 
        ssn_signature: ssn_fingerprint,
        user: user
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([issuer])
    end

    context 'User has profile with matching SSN signature' do
      let(:user2) { create(:user, :fully_registered) }
      let!(:profile2) do
        create(
          :profile,
          :active,
          :facial_match_proof,
          :with_pii,
          ssn_signature: ssn_fingerprint,
          user: user2
        )
      end
      context 'with Matching User with profile linked to SP' do
      
        before do
          link_identity(user, current_sp, 2)
          link_identity(user2, current_sp, 2)
        end

        scenario 'User sign in shows duplicate profile detected' do
          visit_idp_from_ial2_oidc_sp(facial_match_required: true)
          sign_in_user(user)
          fill_in_code_with_last_phone_otp
          click_submit_default
          expect(page).to have_current_path(duplicate_profiles_detected_path(source: :sign_in))
        end
      end

      context 'with Matching User with profile but not linked to SP yet' do
        before do
          link_identity(user, current_sp, 2)
          identity = user.identities.find_by(service_provider: current_sp.issuer)
          identity.update(verified_attributes: ["email", "given_name", "family_name", "social_security_number"])
        end

        scenario 'User sign in gets to  SP' do
          visit_idp_from_ial2_oidc_sp(facial_match_required: true)
          sign_in_user(user)
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect(oidc_redirect_url).to match('http://localhost:7654/auth/result')
        end
      end

      context 'Matching User with profile but linked to different sp' do
        let(:different_sp) { create(:service_provider, :active, issuer: 'urn:gov:gsa:openidconnect:sp:server2') }

        before do
          link_identity(user, current_sp, 2)
          link_identity(user2, different_sp, 2)
        end

        scenario 'User sign in shows duplicate profile detected' do
          visit_idp_from_ial2_oidc_sp(facial_match_required: true)
          sign_in_user(user)
          fill_in_code_with_last_phone_otp
          click_submit_default
          expect(page).to have_current_path(duplicate_profiles_detected_path(source: :sign_in))
        end
      end
    end

    # context 'with Matching User with profile but not linked to SP yet' do
    #   let!(:profile) { create(:profile, :active, :facial_match_proof, :with_pii, user: user) }
    #   before do
    #     allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
    #       .and_return([issuer])
    #   end

    #   scenario 'User sign in links identity and goes to SP' do
    #     visit_idp_from_ial2_oidc_sp(facial_match_required: true)
    #     sign_in_user(user)
    #     fill_in_code_with_last_phone_otp
    #     click_submit_default

    #     expect(page).to have_current_path(root_path)

    #     identity = user.identities.find_by(service_provider: current_sp.issuer)
    #     expect(identity).not_to be_nil
    #     expect(identity.ial).to eq(2)
    #     expect(identity.last_consented_at).not_to be_nil
    #   end
    # end
  end

  context 'with One account disabled for SP' do

  end
end
