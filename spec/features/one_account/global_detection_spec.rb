require 'rails_helper'

RSpec.feature 'One Account Global Detection' do
  include OidcAuthHelper

  let(:issuer) { OidcAuthHelper::OIDC_ISSUER }
  let(:current_sp) { ServiceProvider.find_by(issuer: issuer) }
  let(:redirect_url_pattern) { 'http://localhost:7654/auth/result' }
  let(:verified_attributes) do
    ['email', 'given_name', 'family_name', 'social_security_number']
  end
  let(:pii_attrs) do
    {
      first_name: 'Faker',
      last_name: 'Fakerson',
      ssn: '123-45-6789',
      dob: '1980-01-01',
      address1: '123 Main St',
      city: 'Anytown',
      state: 'NY',
      zipcode: '12345',
    }
  end
  let(:different_pii_attrs) do
    pii_attrs.merge(ssn: '987-65-4321')
  end

  let(:user1) { create(:user, :fully_registered) }
  let(:user2) { create(:user, :fully_registered) }

  let!(:profile1) do
    create(
      :profile,
      :active,
      :facial_match_proof,
      pii: pii_attrs,
      user: user1,
    )
  end
  let!(:profile2) do
    create(
      :profile,
      :active,
      :facial_match_proof,
      pii: pii_attrs,
      user: user2,
    )
  end

  context 'with global detection enabled' do
    before do
      allow(IdentityConfig.store).to receive(:enable_one_account_global_detection)
        .and_return(true)
      reload_ab_tests
    end

    context 'when two users have matching SSN signatures across any SP' do
      before do
        link_identity(user1, current_sp, 2)
      end

      scenario 'User1 is shown duplicate profiles warning on sign-in' do
        complete_sign_in(user1)

        expect_duplicate_warning
      end

      scenario 'duplicate profile set is created with null service_provider' do
        complete_sign_in(user1)

        dupe_set = DuplicateProfileSet.involving_profile_global(profile_id: profile1.id)
        expect(dupe_set).to be_present
        expect(dupe_set.service_provider).to be_nil
        expect(dupe_set.profile_ids).to match_array([profile1.id, profile2.id])
      end
    end

    context 'when User2 is NOT linked to the same SP' do
      let(:different_sp) do
        create(:service_provider, :active, issuer: 'urn:gov:gsa:openidconnect:sp:different')
      end

      before do
        link_identity(user1, current_sp, 2)
        link_identity(user2, different_sp, 2)
      end

      scenario 'User1 still sees duplicate warning (global ignores SP)' do
        complete_sign_in(user1)

        expect_duplicate_warning
      end
    end

    context 'when User2 has no SP identity at all' do
      before do
        link_identity(user1, current_sp, 2)
        # user2 has no SP identity — but global detection still finds them
      end

      scenario 'User1 still sees duplicate warning' do
        complete_sign_in(user1)

        expect_duplicate_warning
      end
    end

    context 'when SSNs do not match' do
      let!(:profile2) do
        create(
          :profile,
          :active,
          :facial_match_proof,
          pii: different_pii_attrs,
          user: user2,
        )
      end

      before do
        link_identity(user1, current_sp, 2)
        link_identity(user2, current_sp, 2)
      end

      scenario 'User1 is not shown duplicate warning' do
        complete_sign_in(user1)

        expect_no_duplicate_warning
      end
    end

    context 'when User1 signs in to a non-IAL2 SP' do
      before do
        link_identity(user1, current_sp, 2)
      end

      scenario 'User1 is not shown duplicate warning' do
        visit_idp_from_ial1_oidc_sp
        sign_in_user(user1)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path(sign_up_completed_path)
      end
    end

    context 'when User1 signs in to an IAL2 SP that does not require facial match' do
      before do
        link_identity(user1, current_sp, 2)
      end

      scenario 'User1 is not shown duplicate warning' do
        visit_idp_from_ial2_oidc_sp
        sign_in_user(user1)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path(sign_up_completed_path)
      end
    end

    context 'when an existing SP-scoped duplicate set exists' do
      before do
        link_identity(user1, current_sp, 2)
        link_identity(user2, current_sp, 2)
        create(
          :duplicate_profile_set,
          profile_ids: [profile1.id, profile2.id],
          service_provider: issuer,
        )
      end

      scenario 'SP-scoped set is closed and global set is created on sign-in' do
        complete_sign_in(user1)

        expect_duplicate_warning

        sp_set = DuplicateProfileSet.where(service_provider: issuer)
          .where('? = ANY(profile_ids)', profile1.id).first
        expect(sp_set.closed_at).not_to be_nil

        global_set = DuplicateProfileSet.involving_profile_global(profile_id: profile1.id)
        expect(global_set).to be_present
        expect(global_set.service_provider).to be_nil
        expect(global_set.closed_at).to be_nil
      end
    end

    context 'when the SP is not in eligible_one_account_providers' do
      before do
        allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
          .and_return([])
        link_identity(user1, current_sp, 2)
        link_identity(user2, current_sp, 2)
      end

      scenario 'User1 still sees duplicate warning (global bypasses SP eligibility)' do
        complete_sign_in(user1)

        expect_duplicate_warning
      end
    end
  end

  context 'with global detection disabled (SP-scoped behavior)' do
    before do
      allow(IdentityConfig.store).to receive(:enable_one_account_global_detection)
        .and_return(false)
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([issuer])
      reload_ab_tests
    end

    context 'when both users are linked to the same eligible SP' do
      before do
        link_identity(user1, current_sp, 2)
        link_identity(user2, current_sp, 2)
      end

      scenario 'User1 is shown duplicate profiles warning' do
        complete_sign_in(user1)

        expect_duplicate_warning
      end

      scenario 'duplicate profile set is created with service_provider set' do
        complete_sign_in(user1)

        dupe_set = DuplicateProfileSet.involving_profile(
          profile_id: profile1.id,
          service_provider: issuer,
        )
        expect(dupe_set).to be_present
        expect(dupe_set.service_provider).to eq(issuer)
      end
    end

    context 'when User2 is linked to a different SP' do
      let(:different_sp) do
        create(:service_provider, :active, issuer: 'urn:gov:gsa:openidconnect:sp:different')
      end

      before do
        link_identity(user1, current_sp, 2)
        link_identity(user2, different_sp, 2)
        mark_identity_verified_for_one_account(user1)
      end

      scenario 'User1 is NOT shown duplicate warning (SP-scoped only checks same SP)' do
        complete_sign_in(user1)

        expect_no_duplicate_warning
      end
    end

    context 'when SP is not in eligible_one_account_providers' do
      before do
        allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
          .and_return([])
        link_identity(user1, current_sp, 2)
        link_identity(user2, current_sp, 2)
        mark_identity_verified_for_one_account(user1)
      end

      scenario 'User1 is NOT shown duplicate warning (SP not eligible)' do
        complete_sign_in(user1)

        expect_no_duplicate_warning
      end
    end
  end

  context 'rollback: global detection disabled after being enabled' do
    let!(:orphaned_global_set) do
      create(
        :duplicate_profile_set, :global,
        profile_ids: [profile1.id, profile2.id]
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:enable_one_account_global_detection)
        .and_return(false)
      allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
        .and_return([issuer])
      link_identity(user1, current_sp, 2)
      link_identity(user2, current_sp, 2)
      reload_ab_tests
    end

    scenario 'SP-scoped duplicate set is created; orphaned global set is ignored' do
      complete_sign_in(user1)

      expect_duplicate_warning

      sp_set = DuplicateProfileSet.involving_profile(
        profile_id: profile1.id,
        service_provider: issuer,
      )
      expect(sp_set).to be_present
      expect(sp_set.service_provider).to eq(issuer)

      expect(orphaned_global_set.reload.closed_at).to be_nil
    end
  end

  def complete_sign_in(user, facial_match_required: true)
    visit_idp_from_ial2_oidc_sp(facial_match_required: facial_match_required)
    sign_in_user(user)
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def expect_duplicate_warning
    expect(page).to have_current_path(duplicate_profiles_detected_path(source: :sign_in))
  end

  def expect_no_duplicate_warning
    expect(page).not_to have_current_path(duplicate_profiles_detected_path(source: :sign_in))
  end

  def mark_identity_verified_for_one_account(user)
    identity = user.identities.find_by(service_provider: current_sp.issuer)
    identity.update!(verified_attributes: verified_attributes)
  end
end
