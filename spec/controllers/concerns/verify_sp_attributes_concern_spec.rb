require 'rails_helper'

RSpec.describe VerifySpAttributesConcern do
  controller ApplicationController do
    # ApplicationController already includes VerifySpAttributesConcern
  end

  describe '#consent_has_expired?' do
    let(:sp_session_identity) { build(:service_provider_identity, user: user) }
    let(:user) { build(:user) }

    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:sp_session_identity).and_return(sp_session_identity)
    end

    subject(:consent_has_expired?) { controller.consent_has_expired?(sp_session_identity) }

    context 'when there is no sp_session_identity' do
      let(:sp_session_identity) { nil }
      it 'is false' do
        expect(consent_has_expired?).to eq(false)
      end
    end

    context 'when there is no last_consented_at' do
      it 'is true' do
        expect(consent_has_expired?).to eq(true)
      end
    end

    context 'when last_consented_at within one year' do
      let(:sp_session_identity) { build(:service_provider_identity, last_consented_at: 5.days.ago) }

      it 'is false' do
        expect(consent_has_expired?).to eq(false)
      end
    end

    context 'when the last_consented_at is older than a year ago' do
      let(:sp_session_identity) do
        build(:service_provider_identity, last_consented_at: 2.years.ago)
      end

      it 'is true' do
        expect(consent_has_expired?).to eq(true)
      end
    end

    context 'when last_consented_at is nil but created_at is within a year' do
      let(:sp_session_identity) do
        build(:service_provider_identity, last_consented_at: nil, created_at: 4.days.ago)
      end

      it 'is false' do
        expect(consent_has_expired?).to eq(false)
      end
    end

    context 'when last_consented_at is nil and created_at is older than a year' do
      let(:sp_session_identity) do
        build(:service_provider_identity, last_consented_at: nil, created_at: 4.years.ago)
      end

      it 'is true' do
        expect(consent_has_expired?).to eq(true)
      end
    end

    context 'when the identity has been soft-deleted (consent has been revoked)' do
      let(:sp_session_identity) do
        build(
          :service_provider_identity,
          deleted_at: 1.day.ago,
          last_consented_at: 2.years.ago,
        )
      end

      it 'is false' do
        expect(consent_has_expired?).to eq(false)
      end
    end

    context 'when there is an active profile' do
      let(:sp_session_identity) do
        create(:service_provider_identity, last_consented_at: 15.days.ago, user: user)
      end

      before do
        create(:profile, :active, verified_at: verified_at, user: user)
      end

      context 'when the active profile was verified after last_consented_at' do
        let(:verified_at) { 5.days.ago }
        it 'is true because the new verified data needs to be consented to sharing' do
          expect(consent_has_expired?).to eq(true)
        end
      end

      context 'when the active profile was verified before last_consented_at' do
        let(:verified_at) { 20.days.ago }
        it 'is false' do
          expect(consent_has_expired?).to eq(false)
        end
      end
    end
  end

  describe '#consent_was_revoked?' do
    let(:sp_session_identity) { build(:service_provider_identity) }

    before do
      allow(controller).to receive(:sp_session_identity).and_return(sp_session_identity)
    end

    subject(:consent_was_revoked?) { controller.consent_was_revoked?(sp_session_identity) }

    context 'when there is no sp_session_identity' do
      let(:sp_session_identity) { nil }
      it 'is false' do
        expect(consent_was_revoked?).to eq(false)
      end
    end

    context 'when the sp_session_identity exists and has not been deleted' do
      it 'is false' do
        expect(consent_was_revoked?).to eq(false)
      end
    end

    context 'when the sp_session_identity exists and has been deleted' do
      let(:sp_session_identity) { build(:service_provider_identity, deleted_at: 2.days.ago) }

      it 'is false' do
        expect(consent_was_revoked?).to eq(true)
      end
    end
  end

  describe '#needs_completion_screen_reason' do
    let(:sp_session_identity) do
      build(
        :service_provider_identity,
        user: user,
        verified_attributes: verified_attributes,
      )
    end
    let(:sp_session) { {} }
    let(:user) { build(:user) }
    let(:verified_attributes) { nil }

    subject(:needs_completion_screen_reason) { controller.needs_completion_screen_reason }

    before do
      allow(controller).to receive(:sp_session).and_return(sp_session)
      allow(controller).to receive(:current_user).and_return(user)
    end

    context 'with an issuer' do
      let(:issuer) { sp_session_identity.service_provider }
      let(:requested_attributes) { nil }
      let(:sp_session) do
        {
          issuer: issuer,
          requested_attributes: requested_attributes,
          request_url: 'http://localhost',
        }
      end

      context 'when the sp_session_identity has not been saved' do
        it 'is :new_sp' do
          expect(needs_completion_screen_reason).to eq(:new_sp)
        end
      end

      context 'when the sp_session_identity has been saved' do
        before { sp_session_identity.save! }

        context 'when requested attributes are nil' do
          let(:requested_attributes) { nil }
          it 'is nil' do
            expect(needs_completion_screen_reason).to be_nil
          end
        end

        context 'when requested attributes exist and are not verified' do
          let(:requested_attributes) { ['first_name'] }
          let(:verified_attributes) { nil }
          it 'is :new_attributes' do
            expect(needs_completion_screen_reason).to eq(:new_attributes)
          end
        end

        context 'when requested attributes are verified' do
          let(:requested_attributes) { ['first_name'] }
          let(:verified_attributes) { ['first_name'] }

          it 'is nil' do
            expect(needs_completion_screen_reason).to be_nil
          end
        end
      end
    end

    context 'without an issuer' do
      it 'is nil' do
        expect(needs_completion_screen_reason).to be_nil
      end
    end
  end
end
