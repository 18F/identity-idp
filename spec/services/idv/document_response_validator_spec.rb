require 'rails_helper'

RSpec.describe Idv::DocumentResponseValidator do
  subject(:validator) { described_class.new(form_response:) }

  let(:success) { true }
  let(:errors) { {} }
  let(:extra) { {} }

  let(:form_response) do
    Idv::DocAuthFormResponse.new(success:, errors:, extra:)
  end

  describe '#response' do
    let(:form_response) { double('form_response') }
    let(:doc_pii_response) { double('doc_pii_response') }
    let(:client_response) { double('client_response') }

    context 'when the form response fails' do
      before do
        allow(form_response).to receive(:success?).and_return(false)
      end

      it 'is the form_response' do
        expect(validator.response).to eq(form_response)
      end
    end

    context 'when the form response succeeds' do
      before do
        allow(form_response).to receive(:success?).and_return(true)
      end

      context 'and there is no doc_pii_response' do
        context 'and there is no client_response' do
          # shouldn't happen
          it 'is nil' do
            expect(validator.response).to eq(nil)
          end
        end

        context 'and there is a client response' do
          before do
            validator.client_response = client_response
          end

          it 'is the client_response' do
            expect(validator.response).to eq(client_response)
          end
        end
      end

      context 'and there is a doc_pii_response' do
        before do
          validator.doc_pii_response = doc_pii_response
        end

        context 'which passes' do
          before do
            allow(doc_pii_response).to receive(:success?).and_return(true)
          end

          context 'and there is no client_response' do
            # shouldn't happen
            it 'is nil' do
              expect(validator.response).to eq(nil)
            end
          end

          context 'and there is a client response' do
            before do
              validator.client_response = client_response
            end

            it 'is the client_response' do
              expect(validator.response).to eq(client_response)
            end
          end
        end

        context 'which fails' do
          before do
            allow(doc_pii_response).to receive(:success?).and_return(false)
          end

          it 'is the doc_pii_response' do
            expect(validator.response).to eq(doc_pii_response)
          end
        end
      end
    end
  end
end
