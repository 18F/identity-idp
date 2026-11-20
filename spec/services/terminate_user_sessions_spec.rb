# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TerminateUserSessions do
  let(:user) { create(:user, :fully_registered) }
  let(:kept_session_id) { SecureRandom.hex }
  let(:other_session_id) { SecureRandom.hex }
  let!(:kept_identity) do
    create(
      :service_provider_identity, user:, rails_session_id: kept_session_id,
                                  access_token: SecureRandom.hex
    )
  end
  let!(:other_identity) do
    create(
      :service_provider_identity, user:, rails_session_id: other_session_id,
                                  access_token: SecureRandom.hex
    )
  end
  let!(:unrelated_identity) do
    create(:service_provider_identity, rails_session_id: SecureRandom.hex, access_token: 'x')
  end

  before do
    [kept_session_id, other_session_id, unrelated_identity.rails_session_id].each do |id|
      OutOfBandSessionAccessor.new(id).put_empty_user_session(5.minutes)
    end
  end

  describe '#call' do
    context 'with a session to keep' do
      subject(:call) do
        described_class.new(user:, except_session_id: kept_session_id).call
      end

      it 'deletes every other recorded session of the person and leaves the kept one' do
        call

        expect(OutOfBandSessionAccessor.new(other_session_id).exists?).to eq(false)
        expect(OutOfBandSessionAccessor.new(kept_session_id).exists?).to eq(true)
      end

      it 'clears the access token and session pointer of the ended sessions only' do
        call

        expect(other_identity.reload).to have_attributes(access_token: nil, rails_session_id: nil)
        expect(kept_identity.reload.access_token).to be_present
        expect(kept_identity.rails_session_id).to eq(kept_session_id)
      end

      it 'refuses the ended session\'s access token at the user-information verifier' do
        token = other_identity.access_token
        expect(AccessTokenVerifier.new("Bearer #{token}").submit.first.success?).to eq(true)

        call

        expect(AccessTokenVerifier.new("Bearer #{token}").submit.first.success?).to eq(false)
      end
    end

    context 'without a session to keep' do
      subject(:call) { described_class.new(user:).call }

      it 'ends every recorded session of the person' do
        call

        expect(OutOfBandSessionAccessor.new(kept_session_id).exists?).to eq(false)
        expect(OutOfBandSessionAccessor.new(other_session_id).exists?).to eq(false)
        expect(user.identities.where.not(access_token: nil)).to be_empty
        expect(user.identities.where.not(rails_session_id: nil)).to be_empty
      end

      it 'leaves other people\'s sessions alone' do
        call

        other_session = OutOfBandSessionAccessor.new(unrelated_identity.rails_session_id)
        expect(other_session.exists?).to eq(true)
        expect(unrelated_identity.reload.access_token).to eq('x')
      end
    end
  end
end
