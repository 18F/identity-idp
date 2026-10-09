require 'rails_helper'

RSpec.describe Billing::SpReturnLogWriter do
  let(:profile_sp) { create(:service_provider) }
  let(:active_profile) do
    create(:profile, :active, :verified, initiating_service_provider: profile_sp)
  end
  let(:user) { create(:user, profiles: [active_profile]) }
  let(:issuer) { create(:service_provider).issuer }
  let(:request_id) { SecureRandom.hex }

  around { |ex| freeze_time { ex.run } }

  describe '.write' do
    it 'writes a direct IAL1 row without profile columns' do
      row = described_class.write(user:, issuer:, ial: 1, request_id:, billable: true)

      expect(row).to be_persisted
      expect(row).to have_attributes(
        user:, issuer:, ial: 1, billable: true, request_id:, access_type: 'direct',
        returned_at: Time.zone.now, profile_id: nil, profile_verified_at: nil,
        profile_requested_issuer: nil
      )
    end

    it 'writes the profile columns for an IAL2 row' do
      row = described_class.write(user:, issuer:, ial: 2, request_id:, billable: true)

      expect(row.profile_id).to eq(active_profile.id)
      expect(row.profile_verified_at).to eq(active_profile.verified_at)
      expect(row.profile_requested_issuer).to eq(profile_sp.issuer)
    end

    it 'leaves the profile columns empty for an IAL2 row when the user has no active profile' do
      user.profiles.update_all(active: false)
      row = described_class.write(user: user.reload, issuer:, ial: 2, request_id:, billable: true)

      expect(row).to have_attributes(
        ial: 2, profile_id: nil, profile_verified_at: nil, profile_requested_issuer: nil,
      )
    end

    it 'writes a delegated row' do
      row = described_class.write(
        user:, issuer:, ial: 2, request_id:, billable: true, access_type: 'delegated',
      )

      expect(row).to have_attributes(access_type: 'delegated', billable: true, ial: 2)
      expect(row).to be_delegated
    end

    context 'when the request id already exists' do
      before { described_class.write(user:, issuer:, ial: 1, request_id:, billable: true) }

      it 'returns nil and writes nothing by default' do
        expect do
          expect(
            described_class.write(user:, issuer:, ial: 1, request_id:, billable: false),
          ).to be_nil
        end.not_to(change { SpReturnLog.count })
      end

      it 'retries once with a random id and billable false when asked' do
        row = nil
        expect do
          row = described_class.write(
            user:, issuer:, ial: 1, request_id:, billable: true, retry_on_collision: true,
          )
        end.to change { SpReturnLog.count }.by(1)

        expect(row.billable).to eq(false)
        expect(row.request_id).not_to eq(request_id)
      end

      it 'does not retry a non-billable collision' do
        expect do
          described_class.write(
            user:, issuer:, ial: 1, request_id:, billable: false, retry_on_collision: true,
          )
        end.not_to(change { SpReturnLog.count })
      end

      it 'leaves an enclosing transaction usable after the collision' do
        SpReturnLog.transaction do
          described_class.write(
            user:, issuer:, ial: 1, request_id:, billable: true, retry_on_collision: true,
          )
          expect(SpReturnLog.count).to eq(2)
          expect(SpReturnLog.create!(request_id: SecureRandom.hex, ial: 1, issuer:, user:))
            .to be_persisted
        end
        expect(SpReturnLog.count).to eq(3)
      end
    end
  end
end
