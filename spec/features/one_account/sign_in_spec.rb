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
  let(:service_provider) do
    create(:service_provider, :active, issuer: 'urn:gov:gsa:openidconnect:sp:server')
  end
  let(:pii_attrs) do
    {
      first_name: 'John',
      last_name: 'Doe',
      ssn: '123-45-6789',
      dob: '1980-01-01',
      address1: '123 Main St',
      city: 'Anytown',
      state: 'NY',
      zipcode: '12345',
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
        pii: pii_attrs,
        user: user,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([issuer])
    end

    context 'User2 has profile with matching SSN signature' do
      let(:user2) { create(:user, :fully_registered) }
      let!(:profile2) do
        create(
          :profile,
          :active,
          :facial_match_proof,
          pii: pii_attrs,
          user: user2,
        )
      end
      context 'with User2 with profile linked to SP' do
        before do
          link_identity(user, current_sp, 2)
          link_identity(user2, current_sp, 2)
        end

        scenario 'User1 sign in shows duplicate profile detected' do
          visit_idp_from_ial2_oidc_sp(facial_match_required: true)
          sign_in_user(user)
          fill_in_code_with_last_phone_otp
          click_submit_default
          expect(page).to have_current_path(duplicate_profiles_detected_path(source: :sign_in))
        end
      end

      context 'with User2 with profile and linked to SP but signing into other SP' do
        before do
          link_identity(user, current_sp, 2)
          link_identity(user2, current_sp, 2)
        end

        scenario 'User1 sign in to different SP does not show duplicate profile detected' do
          visit_idp_from_ial1_oidc_sp
          sign_in_user(user)
          fill_in_code_with_last_phone_otp
          click_submit_default
          expect(page).to have_current_path(sign_up_completed_path)
        end
      end

      context 'with User2 with profile but not linked to SP yet' do
        before do
          link_identity(user, current_sp, 2)
          identity = user.identities.find_by(service_provider: current_sp.issuer)
          identity.update(
            verified_attributes: ['email', 'given_name', 'family_name',
                                  'social_security_number'],
          )
        end

        scenario 'User sign in gets to  SP' do
          visit_idp_from_ial2_oidc_sp(facial_match_required: true)
          sign_in_user(user)
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect(oidc_redirect_url).to match('http://localhost:7654/auth/result')
        end
      end

      context 'User2 with profile but linked to different sp' do
        let(:different_sp) do
          create(:service_provider, :active, issuer: 'urn:gov:gsa:openidconnect:sp:server2')
        end

        before do
          identity = link_identity(user, current_sp, 2)
          link_identity(user2, different_sp, 2)
          identity.update(
            verified_attributes: ['email', 'given_name', 'family_name',
                                  'social_security_number'],
          )
        end

        scenario 'User is redirected to SP without issue' do
          visit_idp_from_ial2_oidc_sp(facial_match_required: true)
          sign_in_user(user)
          fill_in_code_with_last_phone_otp
          click_submit_default

          expect(oidc_redirect_url).to match('http://localhost:7654/auth/result')
        end
      end
    end

    context 'User2 has profile with non-matching SSN signature' do
      let(:user2) { create(:user, :fully_registered) }
      let!(:profile2) do
        create(
          :profile,
          :active,
          :facial_match_proof,
          ssn_signature: 'bbb',
          user: user2,
        )
      end

      before do
        link_identity(user, current_sp, 2)
        link_identity(user2, current_sp, 2)
      end

      scenario 'User1 sign in does not show duplicate profile detected' do
        visit_idp_from_ial2_oidc_sp(facial_match_required: true)
        sign_in_user(user)
        fill_in_code_with_last_phone_otp
        click_submit_default
        expect(page).to have_current_path(sign_up_completed_path)
      end
    end
  end
end
