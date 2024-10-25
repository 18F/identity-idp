# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureDocvResultsJob do
  let(:job) { described_class.new }
  let(:user) { create(:user) }
  let(:document_capture_session) do
    DocumentCaptureSession.create(user:).tap do |dcs|
      dcs.socure_docv_transaction_token = '1234'
    end
  end
  let(:socure_idplus_base_url) { 'https://example.com' }
  let(:decision_value) { 'accept' }
  let(:expiration_date) { "#{1.year.from_now.year}-01-01" }

  let(:analytics) { FakeAnalytics.new }

  before do
    allow(IdentityConfig.store).to receive(:socure_idplus_base_url).
      and_return(socure_idplus_base_url)
  end

  describe '#perform' do
    subject(:perform) do
      job.perform(document_capture_session_uuid: document_capture_session.uuid)
    end

    let(:socure_response_body) do
      # ID+ v3.0 API Predictive Document Verification response
      {
        referenceId: 'a1234b56-e789-0123-4fga-56b7c890d123',
        previousReferenceId: 'e9c170f2-b3e4-423b-a373-5d6e1e9b23f8',
        documentVerification: {
          reasonCodes: %w[I831 R810],
          documentType: {
            type: 'Drivers License',
            country: 'USA',
            state: 'NY',
          },
          decision: {
            name: 'lenient',
            value: decision_value,
          },
          documentData: {
            firstName: 'Dwayne',
            surName: 'Denver',
            fullName: 'Dwayne Denver',
            address: '123 Example Street, New York City, NY 10001',
            parsedAddress: {
              physicalAddress: '123 Example Street',
              physicalAddress2: 'New York City NY 10001',
              city: 'New York City',
              state: 'NY',
              country: 'US',
              zip: '10001',
            },
            documentNumber: '000000000',
            dob: '2000-01-01',
            issueDate: '2020-01-01',
            expirationDate: expiration_date,
          },
        },
        customerProfile: {
          customerUserId: document_capture_session.uuid,
          userId: 'u8JpWn4QsF3R7tA2',
        },
      }
    end

    before do
      stub_request(:post, 'https://example.com/api/3.0/EmailAuthScore').
        to_return(
          headers: {
            'Content-Type' => 'application/json',
          },
          body: JSON.generate(socure_response_body),
        )
    end

    it 'stores the result from the socure document verification request' do
      perform

      document_capture_session.reload
      document_capture_session_result = document_capture_session.load_result
      expect(document_capture_session_result.success).to eq(true)
      expect(document_capture_session_result.pii[:first_name]).to eq('Dwayne')
      expect(document_capture_session_result.attention_with_barcode).to eq(false)
      expect(document_capture_session_result.doc_auth_success).to eq(true)
      expect(document_capture_session_result.selfie_status).to eq(:not_processed)
    end
  end
end
