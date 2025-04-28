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
    profile = create(
      :profile,
      :active,
      :facial_match_proof,
      user: user,
      initiating_service_provider_issuer: sp.issuer,
    )
    profile.encrypt_pii(active_pii, user.password)
    profile.save
    profile
  end
  let(:issuer) { sp.issuer }

  describe '#validate_user_does_not_have_duplicate_profile' do
    context 'when service provider eligible for duplicate profile check' do
      before do
        allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
          .and_return([sp.issuer])
      end

      context 'when user has active IAL2 profile' do
        context 'when user has already been verified for duplicate profile' do
          let(:user2) { create(:user, :fully_registered) }
          let!(:profile2) do
            profile2 = create(
              :profile, :active,
              :facial_match_proof,
              user: user2,
              initiating_service_provider_issuer: issuer
            )
            profile2.encrypt_pii(active_pii, user2.password)
            profile2
          end

          before do
            session[:encrypted_profiles] = {
              profile.id.to_s => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
            }

            DuplicateProfileConfirmation.create(
              profile_id: profile.id,
              confirmed_at: Time.zone.now,
              duplicate_profile_ids: [profile2.id],
            )
          end
          it 'does not create a new duplicate profile confirmation' do
            expect(DuplicateProfileConfirmation.where(profile_id: profile.id).size).to eq(1)
            dupe_profile_checker = DuplicateProfileChecker.new(
              user: user, user_session: session,
              sp: sp
            )
            dupe_profile_checker.check_for_duplicate_profiles

            expect(DuplicateProfileConfirmation.where(profile_id: profile.id).size).to eq(1)
          end

          context 'when a new duplicate profile has been added since' do
          end
        end

        context 'when user has not been checked for duplicate profile' do
          context 'when user does not have other accounts with matching profile' do
            let(:user2) { create(:user, :proofed_with_selfie) }

            it 'does not create a new duplicate profile confirmation' do
              dupe_profile_checker = DuplicateProfileChecker.new(
                user: user, user_session: session,
                sp: sp
              )
              dupe_profile_checker.check_for_duplicate_profiles

              expect(DuplicateProfileConfirmation.where(profile_id: profile.id)).to be_empty
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

            before do
              session[:encrypted_profiles] = {
                profile.id.to_s => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
              }
            end

            it 'creates a new duplicate profile confirmation entry' do
              dupe_profile_checker = DuplicateProfileChecker.new(
                user: user, user_session: session,
                sp: sp
              )
              dupe_profile_checker.check_for_duplicate_profiles

              expect(DuplicateProfileConfirmation.where(profile_id: profile.id).first).to be_present
            end
          end
        end
      end

      context 'when user does not have active IAL2 profile' do
        let(:user) { create(:user, :proofed) }
        it 'does not create a new duplicate profile confirmation' do
          dupe_profile_checker = DuplicateProfileChecker.new(
            user: user,
            user_session: session,
            sp: sp,
          )
          dupe_profile_checker.check_for_duplicate_profiles

          expect(DuplicateProfileConfirmation.where(profile_id: user.active_profile.id)).to be_empty
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

          expect(DuplicateProfileConfirmation.where(profile_id: profile.id)).to be_empty
        end
      end
    end

    context 'when service provider not eligible for duplicate profile check' do
      before do
        allow(IdentityConfig.store).to receive(:eligible_one_account_providers).and_return([])
      end

      it 'does not create a new duplicate profile confirmation' do
        dupe_profile_checker = DuplicateProfileChecker.new(
          user: user,
          user_session: session,
          sp: sp,
        )
        dupe_profile_checker.check_for_duplicate_profiles

        expect(DuplicateProfileConfirmation.where(profile_id: profile.id)).to be_empty
      end
    end
  end
end
