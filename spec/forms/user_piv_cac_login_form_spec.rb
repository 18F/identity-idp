require 'rails_helper'

describe UserPivCacLoginForm do
  let(:user) { create(:user) }
  let(:piv_cac_configuration) do
    create(:piv_cac_configuration, user_id: user.id, x509_dn_uuid: 'random-uuid-for-x509-subject')
  end
  let(:nonce) { 'nonce' }
  let(:piv_cac_required) { false }
  let(:form) { described_class.new(token: token, nonce: nonce, piv_cac_required: piv_cac_required) }

  describe '#submit' do
    before(:each) do
      allow(PivCacService).to receive(:decode_token).with(token) { token_response }
    end

    context 'when token is valid' do
      let(:token) { 'good-token' }

      let(:token_response) do
        {
          'uuid' => piv_cac_configuration.x509_dn_uuid,
          'subject' => 'x509-subject',
          'nonce' => nonce,
        }
      end

      it 'returns FormResponse with success: true' do
        result = form.submit

        expect(result.success?).to eq true
        expect(result.errors).to eq({})
        expect(result.extra).to eq({ key_id: nil })
      end
    end

    context 'when token is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => nonce, 'key_id' => 'foo' }
      end

      it 'returns FormResponse with success: false' do
        result = form.submit

        expect(result.success?).to eq false
        expect(result.errors).to eq({ type: 'token.bad' })
        expect(result.extra).to eq({ key_id: 'foo' })
      end
    end

    context 'when nonce is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => bad_nonce, 'key_id' => 'foo' }
      end
      let(:bad_nonce) { nonce + 'X' }

      it 'returns FormResponse with success: false' do
        result = form.submit

        expect(result.success?).to eq false
        expect(result.errors).to eq({ type: 'token.invalid' })
        expect(result.extra).to eq({ key_id: 'foo' })
      end
    end

    context 'when piv cac is required' do
      let(:token) { 'good-token' }
      let(:piv_cac_required) { true }

      it 'returns FormResponse with success: true when the token indicates auth cert' do
        resp = { 'nonce' => nonce, 'is_auth_cert' => true,
                 'uuid' => piv_cac_configuration.x509_dn_uuid }
        allow(PivCacService).to receive(:decode_token).with(token) { resp }

        result = form.submit

        expect(result.success?).to eq true
      end

      it 'returns FormResponse with success: false when the token indicates not an auth cert' do
        resp = { 'nonce' => nonce, 'is_auth_cert' => false,
                 'uuid' => piv_cac_configuration.x509_dn_uuid }
        allow(PivCacService).to receive(:decode_token).with(token) { resp }

        result = form.submit

        expect(result.success?).to eq false
        expect(result.errors).to eq({ type: 'certificate.not_auth_cert' })
      end
    end

    context 'when token is missing' do
      let(:token) {}

      it 'returns FormResponse with success: false' do
        result = form.submit

        expect(result.success?).to eq false
      end
    end
  end
end
