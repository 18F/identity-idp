require 'rails_helper'

RSpec.describe StsConsentForm do
  let(:user) { create(:user) }
  let(:target_app) { 'urn:gov:gsa:openidconnect:sp:target' }
  let(:actor_app) { 'urn:gov:gsa:openidconnect:sp:broker' }

  subject(:form) { described_class.new(user:, target_app:, actor_app:) }

  before do
    allow(IdentityConfig.store).to receive(:sts_consent_expiration_in_days).and_return(365)
  end

  describe '#submit' do
    context 'when consent is given' do
      let(:params) { { consent_given: 'consented' } }

      it 'returns a successful response' do
        result = form.submit(params)

        expect(result.success?).to eq(true)
      end

      it 'persists a UserConsentSts record for the user, target_app, and actor_app' do
        expect { form.submit(params) }.to change { UserConsentSts.count }.by(1)

        consent = UserConsentSts.last
        expect(consent.user).to eq(user)
        expect(consent.target_app).to eq(target_app)
        expect(consent.actor_app).to eq(actor_app)
        expect(consent.is_revoked).to eq(false)
      end

      it 'does not create a duplicate when an active consent already exists' do
        UserConsentSts.create!(user:, target_app:, actor_app:)

        expect { form.submit(params) }.not_to change { UserConsentSts.count }
      end

      it 'refreshes an expired consent so it becomes valid again' do
        consent = UserConsentSts.create!(user:, target_app:, actor_app:)
        consent.update!(created_at: 366.days.ago)

        expect(form.submit(params).success?).to eq(true)
        expect(consent.reload.unexpired?).to eq(true)
      end

      it 'creates a new record when the prior consent for the triple was revoked' do
        revoked = UserConsentSts.create!(user:, target_app:, actor_app:, is_revoked: true)

        expect { form.submit(params) }.to change { UserConsentSts.count }.by(1)

        expect(revoked.reload.is_revoked).to eq(true)
        new_consent = UserConsentSts.active.find_by(user:, target_app:, actor_app:)
        expect(new_consent).to be_present
        expect(new_consent.id).not_to eq(revoked.id)
      end
    end

    context 'when consent is not given' do
      let(:params) { { consent_given: '' } }

      it 'returns an unsuccessful response with a required_checkbox error' do
        result = form.submit(params)

        expect(result.success?).to eq(false)
        expect(result.errors[:consent_given]).to be_present
      end

      it 'does not persist a UserConsentSts record' do
        expect { form.submit(params) }.not_to change { UserConsentSts.count }
      end
    end
  end
end
