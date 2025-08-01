require 'rails_helper'

RSpec.describe DuplicateProfileChecker do
  let(:user) { create(:user, :fully_registered) }
  let(:session) { {} }
  let(:active_pii) do
    Pii::Attributes.new(
      ssn: '666339999',
    )
  end
  let(:sp) { create(:service_provider) }
  let(:profile) do
    create(
      :profile,
      :active,
      :facial_match_proof,
      user: user,
      initiating_service_provider_issuer: sp.issuer,
    )
  end
  let(:issuer) { sp.issuer }

  describe '#check_for_duplicate_profiles' do
    before do
      profile.encrypt_pii(active_pii, user.password)
      profile.save
      session[:encrypted_profiles] = {
        profile.id.to_s => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
      }
    end

    context 'when user has active IAL2 profile' do
      context 'when user has not been checked for duplicate profile' do
        context 'when user does not have other accounts with matching profile' do
          let(:user2) { create(:user, :proofed_with_selfie) }

          it 'does not create a new duplicate profile confirmation' do
            dupe_profile_checker = DuplicateProfileChecker.new(
              user: user,
              user_session: session,
              sp: sp,
            )
            dupe_profile_checker.check_for_duplicate_profiles

            expect(session[:duplicate_profile_ids]).to be(nil)
          end
        end

        context 'when user has accounts with matching profile' do
          let(:user2) { create(:user, :fully_registered) }
          let!(:profile2) do
            profile = create(
              :profile,
              :active,
              :facial_match_proof,
              user: user2,
              initiating_service_provider_issuer: sp.issuer,
            )
            profile.encrypt_pii(active_pii, user2.password)
            profile.save
          end

          let(:identity) do
            build(
              :service_provider_identity,
              service_provider: sp.issuer,
              ial: 2,
            )
          end

          let(:identity2) do
            build(
              :service_provider_identity,
              service_provider: sp.issuer,
              ial: 2,
            )
          end

          before do
            session[:encrypted_profiles] = {
              profile.id.to_s => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
            }
            user.identities << identity
            user2.identities << identity2
          end

          it 'creates a new duplicate profile confirmation entry' do
            allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
              .and_return([sp.issuer])
            expect(session[:duplicate_profile_ids]).to be(nil)

            dupe_profile_checker = DuplicateProfileChecker.new(
              user: user,
              user_session: session,
              sp: sp,
            )
            dupe_profile_checker.check_for_duplicate_profiles
            expect(session[:duplicate_profile_ids]).to eq([user2.profiles.last.id])
          end
        end
      end
    end

    context 'when user does not have active IAL2 profile' do
      let(:user) { create(:user, :fully_registered) }
      let(:profile) do
        create(
          :profile,
          :active,
          user: user,
          initiating_service_provider_issuer: sp.issuer,
        )
      end
      it 'does not create a new duplicate profile confirmation' do
        dupe_profile_checker = DuplicateProfileChecker.new(
          user: user,
          user_session: session,
          sp: sp,
        )
        dupe_profile_checker.check_for_duplicate_profiles

        expect(session[:duplicate_profile_ids]).to be(nil)
      end
    end

    context 'user does not have profile' do
      let(:user) { create(:user) }
      it 'does not create a new duplicate profile confirmation' do
        dupe_profile_checker = DuplicateProfileChecker.new(
          user: user,
          user_session: session,
          sp: sp,
        )
        dupe_profile_checker.check_for_duplicate_profiles

        expect(session[:duplicate_profile_ids]).to be(nil)
      end
    end
  end
end
