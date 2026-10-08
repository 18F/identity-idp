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

  describe '#update_verified_attributes' do
    let(:user) { create(:user) }
    let(:service_provider) { create(:service_provider) }
    let(:email_address) { user.email_addresses.take }
    let(:sp_session) do
      { issuer: service_provider.issuer, requested_attributes: ['email'] }
    end

    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_sp).and_return(service_provider)
      allow(controller).to receive(:sp_session).and_return(sp_session)
      allow(controller).to receive(:selected_email_id_for_linked_identity).and_return(nil)
      allow(controller).to receive(:resolved_authn_context_result)
        .and_return(double(ialmax?: false, identity_proofing?: false))
    end

    context 'when the identity already has a selected email and consent has expired' do
      before do
        IdentityLinker.new(user, service_provider).link_identity(
          verified_attributes: %i[email],
          email_address_id: email_address.id,
          last_consented_at: 2.years.ago,
        )
        allow(controller).to receive(:selected_email_id_for_linked_identity).and_return(nil)
      end

      it 're-consents without resetting the selected email' do
        expect do
          controller.update_verified_attributes
        end.to_not change { user.reload.last_identity.email_address_id }
          .from(email_address.id)
      end

      it 'updates last_consented_at' do
        freeze_time do
          controller.update_verified_attributes
          expect(user.reload.last_identity.last_consented_at)
            .to be_within(1.second).of(Time.zone.now)
        end
      end

      context 'when the user selected a different email during re-consent' do
        let(:newly_selected_email) { create(:email_address, user: user) }

        before do
          allow(controller).to receive(:selected_email_id_for_linked_identity)
            .and_return(newly_selected_email.id)
        end

        it 'persists the newly selected email over the previously stored one' do
          expect do
            controller.update_verified_attributes
          end.to change { user.reload.last_identity.email_address_id }
            .from(email_address.id).to(newly_selected_email.id)
        end
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

        context 'when user is reverified' do
          let(:verified_at) { 5.days.ago }
          let(:sp_session_identity) do
            build(
              :service_provider_identity,
              user: user,
              last_consented_at: 15.days.ago,
            )
          end
          before do
            create(:profile, :active, verified_at: verified_at, user: user)
          end
          it 'is reverified_after_consent' do
            expect(needs_completion_screen_reason).to eq(:reverified_after_consent)
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

  describe '#reverified_after_consent?' do
    let(:sp_session_identity) { build(:service_provider_identity, user: user) }
    let(:user) { build(:user) }

    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:sp_session_identity).and_return(sp_session_identity)
    end

    subject(:reverified_after_consent?) do
      controller.reverified_after_consent?(sp_session_identity)
    end

    context 'when there is no sp_session_identity' do
      let(:sp_session_identity) { nil }
      it 'is false' do
        expect(reverified_after_consent?).to eq(false)
      end
    end

    context 'when there is no last_consented_at' do
      it 'is false' do
        expect(reverified_after_consent?).to eq(false)
      end
    end

    context 'when last_consented_at within one year' do
      let(:sp_session_identity) { build(:service_provider_identity, last_consented_at: 5.days.ago) }

      it 'is false' do
        expect(reverified_after_consent?).to eq(false)
      end
    end

    context 'when the last_consented_at is older than a year ago' do
      let(:sp_session_identity) do
        build(:service_provider_identity, last_consented_at: 2.years.ago)
      end

      it 'is false' do
        expect(reverified_after_consent?).to eq(false)
      end
    end

    context 'when last_consented_at is nil but created_at is within a year' do
      let(:sp_session_identity) do
        build(:service_provider_identity, last_consented_at: nil, created_at: 4.days.ago)
      end

      it 'is false' do
        expect(reverified_after_consent?).to eq(false)
      end
    end

    context 'when last_consented_at is nil and created_at is older than a year' do
      let(:sp_session_identity) do
        build(:service_provider_identity, last_consented_at: nil, created_at: 4.years.ago)
      end

      it 'is false' do
        expect(reverified_after_consent?).to eq(false)
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
        expect(reverified_after_consent?).to eq(false)
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
          expect(reverified_after_consent?).to eq(true)
        end
      end

      context 'when the active profile was verified before last_consented_at' do
        let(:verified_at) { 20.days.ago }
        it 'is false' do
          expect(reverified_after_consent?).to eq(false)
        end
      end
    end
  end
end
