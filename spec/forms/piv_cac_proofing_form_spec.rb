require 'rails_helper'

describe PivCacProofingForm do
  let(:form) { described_class.new(token: token, nonce: nonce) }

  let(:nonce) { 'nonce' }

  describe '#submit' do
    before(:each) do
      allow(PivCacService).to receive(:decode_token).with(token) { token_response }
    end

    context 'when token is valid on cac' do
      let(:token) { 'good-token' }
      let(:x509_dn_uuid) { 'random-uuid-for-x509-subject' }

      let(:token_response) do
        {
          'uuid' => x509_dn_uuid,
          'subject' => 'O=US, OU=DoD, CN=John.Doe.1234',
          'nonce' => nonce,
          'card_type' => 'cac',
        }
      end

      it 'returns FormResponse with success: true' do
        result = instance_double(FormResponse)
        extra = { cac_first_name_present: true, cac_last_name_present: true, card_type: 'cac',
                  cn_format: 'Aaaa.Aaa.NNNN', cn_present: true, step: 'present_cac' }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
      end
    end

    context 'when token is valid on piv' do
      let(:token) { 'good-token' }
      let(:x509_dn_uuid) { 'random-uuid-for-x509-subject' }

      let(:token_response) do
        {
          'uuid' => x509_dn_uuid,
          'subject' => 'O=US, OU=DoD, CN=John.Doe.1234',
          'nonce' => nonce,
          'card_type' => 'piv',
        }
      end

      it 'returns FormResponse with success: true' do
        result = instance_double(FormResponse)
        extra = { cac_first_name_present: false, cac_last_name_present: false, card_type: 'piv',
                  cn_format: 'Aaaa.Aaa.NNNN', cn_present: true, step: 'present_cac' }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
      end
    end

    context 'when token is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => nonce, 'key_id' => 'foo' }
      end

      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        extra = { cac_first_name_present: false, cac_last_name_present: false, card_type: nil,
                  cn_format: '', cn_present: false, step: 'present_cac', key_id: 'foo' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: { type: 'token.bad' }, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(form.error_type).to eq 'token.bad'
      end
    end

    context 'when nonce is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => bad_nonce, 'key_id' => 'foo' }
      end
      let(:bad_nonce) { nonce + 'X' }

      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        extra = { cac_first_name_present: false, cac_last_name_present: false, card_type: nil,
                  cn_format: '', cn_present: false, step: 'present_cac', key_id: 'foo' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: { type: 'token.invalid' }, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(form.error_type).to eq 'token.invalid'
      end
    end

    context 'when token is missing' do
      let(:token) {}

      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        extra = { cac_first_name_present: false, cac_last_name_present: false, card_type: nil,
                  cn_format: '', cn_present: false, step: 'present_cac' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
      end
    end
  end
end
