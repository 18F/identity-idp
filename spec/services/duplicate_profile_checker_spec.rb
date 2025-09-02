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
      stub_analytics
    end

    context 'when user has active IAL2 profile' do
      context 'when there are no other matching profile' do
        let(:user2) { create(:user, :proofed_with_selfie) }

        it 'does not create a new duplicate profile' do
          dupe_profile_checker = DuplicateProfileChecker.new(
            user: user,
            user_session: session,
            sp: sp,
            analytics: @analytics,
          )
          dupe_profile_checker.check_for_duplicate_profiles
          dupe_profile_object = DuplicateProfile.involving_profile(
            profile_id: profile.id,
            service_provider: sp.issuer,
          )
          expect(dupe_profile_object).to eq(nil)
          expect(@analytics).to_not have_logged_event(:one_account_duplicate_profile_created)
          expect(@analytics).to_not have_logged_event(:one_account_duplicate_profile_updated)
          expect(@analytics).to_not have_logged_event(:one_account_duplicate_profile_closed)
        end
      end

      context 'when there are matching profiles' do
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
          )
        end

        before do
          allow(IdentityConfig.store).to receive(:eligible_one_account_providers)
            .and_return([sp.issuer])
          session[:encrypted_profiles] = {
            profile.id.to_s => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
          }

          allow_any_instance_of(Idv::DuplicateSsnFinder)
            .to receive(:duplicate_facial_match_profiles)
            .and_return([profile2])
        end

        it 'creates a new duplicate profile object entry and tracks analysis' do
          dupe_profile_checker = DuplicateProfileChecker.new(
            user: user,
            user_session: session,
            sp: sp,
            analytics: @analytics,
          )
          dupe_profile_checker.check_for_duplicate_profiles

          dupe_profile_objects = DuplicateProfile.involving_profile(
            profile_id: profile.id,
            service_provider: sp.issuer,
          )
          expect(dupe_profile_objects.profile_ids).to match_array([profile2.id, profile.id])
          expect(@analytics).to have_logged_event(
            :one_account_duplicate_profile_created,
          )
        end

        context 'when duplicate profile already exists' do
          let!(:dupe_profile) do
            create(
              :duplicate_profile,
              profile_ids: [profile.id, profile2.id],
              service_provider: sp.issuer,
            )
          end

          context 'when the profile_ids are the same' do
            it 'does not create a new duplicate profile objects' do
              dupe_profile_checker = DuplicateProfileChecker.new(
                user: user,
                user_session: session,
                sp: sp,
                analytics: @analytics,
              )
              dupe_profile_checker.check_for_duplicate_profiles

              expect(@analytics).not_to have_logged_event(:one_account_duplicate_profile_created)
              expect(@analytics).not_to have_logged_event(:one_account_duplicate_profile_updated)
              expect(@analytics).not_to have_logged_event(:one_account_duplicate_profile_closed)
            end
          end

          context 'when a new profile is found' do
            let!(:profile3) do
              create(
                :profile,
                :active,
                :facial_match_proof,
                user: create(:user, :fully_registered),
              )
            end
            before do
              allow_any_instance_of(Idv::DuplicateSsnFinder)
                .to receive(:duplicate_facial_match_profiles)
                .and_return([profile2, profile3])
            end

            context 'using the same profile already in dupe profile' do
              it 'updates the existing duplicate profile object' do
                dupe_profile_checker = DuplicateProfileChecker.new(
                  user: user,
                  user_session: session,
                  sp: sp,
                  analytics: @analytics,
                )
                dupe_profile_checker.check_for_duplicate_profiles

                updated_dupe_profile = DuplicateProfile.involving_profile(
                  profile_id: profile.id,
                  service_provider: sp.issuer,
                )
                expect(updated_dupe_profile.profile_ids).to match_array(
                  [profile2.id, profile.id,
                   profile3.id],
                )
                expect(@analytics).to have_logged_event(
                  :one_account_duplicate_profile_updated,
                )
              end
            end

            context 'using the new profile not in dupe profile' do
              let!(:dupe_profile) do
                create(
                  :duplicate_profile,
                  profile_ids: [profile3.id, profile2.id],
                  service_provider: sp.issuer,
                )
              end

              it 'updates the existing duplicate profile object' do
                dupe_profile_checker = DuplicateProfileChecker.new(
                  user: user,
                  user_session: session,
                  sp: sp,
                  analytics: @analytics,
                )
                dupe_profile_checker.check_for_duplicate_profiles

                updated_dupe_profile = DuplicateProfile.involving_profile(
                  profile_id: profile.id,
                  service_provider: sp.issuer,
                )
                expect(updated_dupe_profile.profile_ids).to match_array(
                  [profile2.id, profile.id,
                   profile3.id],
                )
                expect(@analytics).to have_logged_event(
                  :one_account_duplicate_profile_updated,
                )
              end
            end
          end

          context 'when no more duplicates are found' do
            before do
              allow_any_instance_of(Idv::DuplicateSsnFinder)
                .to receive(:duplicate_facial_match_profiles)
                .and_return([])
            end

            it 'closes the duplicate profile and tracks analytics' do
              freeze_time do
                dupe_profile_checker = DuplicateProfileChecker.new(
                  user: user,
                  user_session: session,
                  sp: sp,
                  analytics: @analytics,
                )
                dupe_profile_checker.check_for_duplicate_profiles

                dupe_profile.reload
                expect(dupe_profile.closed_at).to eq(Time.zone.now)
                expect(@analytics).to have_logged_event(
                  :one_account_duplicate_profile_closed,
                )
              end
            end
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
          idv_level: 'legacy_unsupervised',
        )
      end

      it 'does not create a new duplicate profile objects' do
        dupe_profile_checker = DuplicateProfileChecker.new(
          user: user,
          user_session: session,
          sp: sp,
          analytics: @analytics,
        )
        dupe_profile_checker.check_for_duplicate_profiles

        dupe_profile_objects = DuplicateProfile.involving_profile(
          profile_id: profile.id,
          service_provider: sp.issuer,
        )
        expect(dupe_profile_objects).to eq(nil)
      end
    end
  end
end
