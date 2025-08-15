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
            dupe_profile_object = DuplicateProfile.involving_profile(
              profile_id: profile.id,
              service_provider: sp.issuer,
            )
            expect(dupe_profile_object).to be_empty
          end
        end

        context 'when user has accounts with matching profile' do
          let(:user2) { create(:user, :fully_registered) }
          let!(:user2_identity) do
            create(
              :service_provider_identity,
              user: user2,
              service_provider: sp.issuer,
            )
          end
          let!(:profile2) do
            create(
              :profile,
              :active,
              :facial_match_proof,
              user: user2,
              initiating_service_provider_issuer: sp.issuer,
            )
          end

          before do
            session[:encrypted_profiles] = {
              profile.id.to_s => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
            }

            allow_any_instance_of(Idv::DuplicateSsnFinder)
              .to receive(:duplicate_facial_match_profiles)
              .and_return([profile2])
          end

          it 'creates a new duplicate profile confirmation entry' do
            allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
              .and_return([sp.issuer])

            dupe_profile_checker = DuplicateProfileChecker.new(
              user: user,
              user_session: session,
              sp: sp,
            )
            dupe_profile_checker.check_for_duplicate_profiles

            dupe_profile_objects = DuplicateProfile.involving_profile(
              profile_id: profile.id,
              service_provider: sp.issuer,
            )
            expect(dupe_profile_objects.first.profile_ids).to eq([profile2.id, profile.id])
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

        dupe_profile_objects = DuplicateProfile.involving_profile(
          profile_id: profile.id,
          service_provider: sp.issuer,
        )
        expect(dupe_profile_objects).to be_empty
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

        dupe_profile_objects = DuplicateProfile.involving_profile(
          profile_id: profile.id,
          service_provider: sp.issuer,
        )

        expect(dupe_profile_objects).to be_empty
      end
    end
  end
end
