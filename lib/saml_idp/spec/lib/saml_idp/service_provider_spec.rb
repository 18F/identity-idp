require 'spec_helper'
module SamlIdp
  describe ServiceProvider do
    subject { described_class.new attributes }
    let(:attributes) { {} }
    let(:cert) { saml_settings.get_sp_cert }
    let(:options) { {} }

    it { is_expected.to respond_to :metadata_url }
    it { is_expected.not_to be_valid }

    describe 'with attributes' do
      let(:attributes) { { metadata_url: } }
      let(:metadata_url) { 'http://localhost:3000/metadata' }

      it 'has a valid metadata_url' do
        expect(subject.metadata_url).to eq(metadata_url)
      end

      it { is_expected.to be_valid }
    end

    describe '#valid_signature' do
      let(:raw_request) { make_saml_request }

      let(:request) do
        SamlIdp::Request.from_deflated_request(
          raw_request
        )
      end

      let(:matching_cert) { cert }

      describe 'the signature is not required' do
        describe 'a matching cert is passed in' do
          it 'returns true' do
            expect(subject.valid_signature?(matching_cert)).to be true
          end
        end

        describe 'a matching cert is not passed in' do
          let(:matching_cert) { nil }

          it 'returns true' do
            expect(subject.valid_signature?(matching_cert)).to be true
          end
        end
      end

      describe 'the signature is required' do
        context 'validate_signature is set to true on the subject' do
          before { subject.validate_signature = true }

          describe 'a matching cert is passed in' do
            it 'returns true' do
              expect(subject.valid_signature?(matching_cert)).to be true
            end
          end

          describe 'a matching cert is not passed in' do
            let(:matching_cert) { nil }
            it 'returns false' do
              expect(subject.valid_signature?(matching_cert)).to be false
            end
          end
        end

        context 'require_signature is passed in via args' do
          describe 'a matching cert is passed in' do
            it 'returns true' do
              expect(subject.valid_signature?(matching_cert, true)).to be true
            end
          end

          describe 'a matching cert is not passed in' do
            let(:matching_cert) { nil }
            it 'returns false' do
              expect(subject.valid_signature?(matching_cert, true)).to be false
            end
          end
        end
      end
    end
  end
end
