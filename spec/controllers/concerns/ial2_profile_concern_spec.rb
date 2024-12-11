require 'rails_helper'

RSpec.describe Ial2ProfileConcern do
  let(:test_controller) do
    Class.new do
      include Ial2ProfileConcern

      attr_accessor :current_user, :user_session, :analytics

      def initialize(current_user:, user_session:, analytics:)
        @current_user = current_user
        @user_session = user_session
        @analytics = analytics
      end
    end
  end

  let(:user) { create(:user) }
  let(:user_session) { {} }
  let(:analytics) { double(Analytics) }
  let(:encryption_error) { Encryption::EncryptionError.new }
  let(:cacher) { double(Pii::Cacher) }
  let(:password) { 'PraiseTheSun!' }

  describe '#cache_profiles' do
    subject { test_controller.new(current_user: user, user_session:, analytics:) }

    context 'when the user has a pending profile' do
      let!(:profile) { create(:profile, :in_person_verification_pending, user:) }

      context 'when the profile can be saved to cache' do
        before do
          allow(cacher).to receive(:save)
          allow(Pii::Cacher).to receive(:new).and_return(cacher)
          subject.cache_profiles(password)
        end

        it 'stores the decrypted profile in cache' do
          expect(cacher).to have_received(:save).with(password, profile)
        end
      end

      context 'when the profile can not be saved to cache' do
        before do
          allow(cacher).to receive(:save).and_raise(encryption_error)
          allow(Pii::Cacher).to receive(:new).and_return(cacher)
          allow(analytics).to receive(:profile_encryption_invalid)
          subject.cache_profiles(password)
        end

        it 'deactivates the profile with reason encryption_error' do
          expect(profile.reload).to have_attributes(
            active: false,
            deactivation_reason: 'encryption_error',
          )
        end

        it 'logs the profile_encryption_invalid analytic' do
          expect(analytics).to have_received(:profile_encryption_invalid).with(
            error: encryption_error.message,
          )
        end
      end
    end

    context 'when the user has an active profile' do
      let!(:profile) { create(:profile, :active, user:) }

      context 'when the profile can be saved to cache' do
        before do
          allow(cacher).to receive(:save)
          allow(Pii::Cacher).to receive(:new).and_return(cacher)
          subject.cache_profiles(password)
        end

        it 'stores the decrypted profile in cache' do
          expect(cacher).to have_received(:save).with(password, profile)
        end
      end

      context 'when the profile can not be saved to cache' do
        before do
          allow(cacher).to receive(:save).and_raise(encryption_error)
          allow(Pii::Cacher).to receive(:new).and_return(cacher)
          allow(analytics).to receive(:profile_encryption_invalid)
          subject.cache_profiles(password)
        end

        it 'deactivates the profile with reason encryption_error' do
          expect(profile.reload).to have_attributes(
            active: false,
            deactivation_reason: 'encryption_error',
          )
        end

        it 'logs the profile_encryption_invalid analytic' do
          expect(analytics).to have_received(:profile_encryption_invalid).with(
            error: encryption_error.message,
          )
        end
      end
    end

    context 'when the user has both an active profile and pending profile' do
      let(:pending_profile) { create(:profile, :in_person_verification_pending, user:) }
      let(:active_profile) { create(:profile, :active, user:) }

      context 'when the active profile was activated before the pending profile was created' do
        before do
          pending_profile.update!(created_at: Time.zone.now)
          active_profile.update!(activated_at: 1.day.ago)
        end

        context 'when the profiles can be saved to cache' do
          before do
            allow(cacher).to receive(:save)
            allow(Pii::Cacher).to receive(:new).and_return(cacher)
            subject.cache_profiles(password)
          end

          it 'stores the decrypted pending profile in cache' do
            expect(cacher).to have_received(:save).with(password, pending_profile)
          end

          it 'stores the decrypted active profile in cache' do
            expect(cacher).to have_received(:save).with(password, active_profile)
          end
        end

        context 'when the profile can not be saved to cache' do
          before do
            allow(cacher).to receive(:save).and_raise(encryption_error)
            allow(Pii::Cacher).to receive(:new).and_return(cacher)
            allow(analytics).to receive(:profile_encryption_invalid)
            subject.cache_profiles(password)
          end

          it 'deactivates the pending profile with reason encryption_error' do
            expect(pending_profile.reload).to have_attributes(
              active: false,
              deactivation_reason: 'encryption_error',
            )
          end

          it 'deactivates the active profile with reason encryption_error' do
            expect(active_profile.reload).to have_attributes(
              active: false,
              deactivation_reason: 'encryption_error',
            )
          end

          it 'logs the profile_encryption_invalid analytic' do
            expect(analytics).to have_received(:profile_encryption_invalid).with(
              error: encryption_error.message,
            ).twice
          end
        end
      end

      context 'when the active profile was activated after the pending profile was created' do
        before do
          pending_profile.update!(created_at: 1.day.ago)
          active_profile.update!(activated_at: Time.zone.now)
        end

        context 'when the profiles can be saved to cache' do
          before do
            allow(cacher).to receive(:save)
            allow(Pii::Cacher).to receive(:new).and_return(cacher)
            subject.cache_profiles(password)
          end

          it 'does not store the decrypted pending profile in cache' do
            expect(cacher).not_to have_received(:save).with(password, pending_profile)
          end

          it 'stores the decrypted active profile in cache' do
            expect(cacher).to have_received(:save).with(password, active_profile)
          end
        end

        context 'when the profile can not be saved to cache' do
          before do
            allow(cacher).to receive(:save).and_raise(encryption_error)
            allow(Pii::Cacher).to receive(:new).and_return(cacher)
            allow(analytics).to receive(:profile_encryption_invalid)
            subject.cache_profiles(password)
          end

          it 'does not deactivate the pending profile with reason encryption_error' do
            expect(pending_profile.reload).to have_attributes(
              active: false,
              deactivation_reason: nil,
            )
          end

          it 'deactivates the active profile with reason encryption_error' do
            expect(active_profile.reload).to have_attributes(
              active: false,
              deactivation_reason: 'encryption_error',
            )
          end

          it 'logs the profile_encryption_invalid analytic' do
            expect(analytics).to have_received(:profile_encryption_invalid).with(
              error: encryption_error.message,
            ).once
          end
        end
      end
    end
  end
end
