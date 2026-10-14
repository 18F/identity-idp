require 'rails_helper'

RSpec.describe AttemptsApi::HistoricalReleaseCheck do
  let(:sp) { create(:service_provider) }
  let(:profile) { create(:profile, :active, :verified, encrypted_attempts_file_reference: 'ref') }

  subject(:check) { described_class.new(profile:, sp:) }

  it 'is false without a profile' do
    expect(described_class.new(profile: nil, sp:).call).to eq([false, :no_user_proofing_event])
  end

  it 'is false without a user proofing event' do
    expect(check.call).to eq([false, :no_user_proofing_event])
  end

  context 'with a user proofing event' do
    before { profile.create_user_proofing_event!(service_provider_ids_sent: sent) }
    let(:sent) { [] }

    it 'is true when the history has not been released to this recipient' do
      expect(check.call).to eq([true, nil])
    end

    context 'already released to this recipient' do
      let(:sent) { [sp.id] }

      it 'is false' do
        expect(check.call).to eq([false, :already_sent])
      end
    end

    it 'is false when the profile has no stored history' do
      profile.update!(encrypted_attempts_file_reference: nil)
      expect(check.call).to eq([false, :no_encrypted_file_reference])
    end
  end
end
