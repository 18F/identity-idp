require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::Proofer do
  let(:applicant) do
    {
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123456789',
      dob: '01/01/1980',
      address1: '123 Main St',
      address2: 'Ste 3',
      city: 'Baton Rouge',
      state: 'LA',
      zipcode: '70802-12345',
      state_id_number: '12345678',
      state_id_jurisdiction: 'LA',
      threatmetrix_session_id: '123456',
      phone: '5551231234',
      email: 'test@example.com',
      request_ip: '127.0.0.1',
      uuid_prefix: 'ABCD',
    }
  end

  let(:verification_request) do
    Proofing::LexisNexis::Ddp::VerificationRequest.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_config,
    )
  end

  let(:issuer) { 'fake-issuer' }
  let(:friendly_name) { 'fake-name' }
  let(:app_id) { 'fake-app-id' }

  # it_behaves_like 'a lexisnexis proofer'

  describe '#send' do
    context 'when the request times out' do
      it 'raises a timeout error' do
        stub_request(
          :post,
          verification_request.url,
        ).to_timeout

        expect { verification_request.send_request }.to raise_error(
          Proofing::TimeoutError,
          'LexisNexis timed out waiting for verification response',
        )
      end
    end

    context 'when the request is made' do
      it 'it looks like the right request' do
        request =
          stub_request(
            :post,
            verification_request.url,
          ).with(
            body: verification_request.body,
            headers: verification_request.headers,
          ).to_return(
            body: LexisNexisFixtures.ddp_success_response_json,
            status: 200,
          )

        verification_request.send_request

        expect(request).to have_been_requested.once
      end
    end
  end

  subject do
    described_class.new(LexisNexisFixtures.example_config.to_h)
  end

  describe '#proof' do
    before do
      ServiceProvider.create(
        issuer: issuer,
        friendly_name: friendly_name,
        app_id: app_id,
      )
      stub_request(
        :post,
        verification_request.url,
      ).to_return(
        body: response_body,
        status: 200,
      )
    end

    context 'when the response is a full match' do
      let(:response_body) { LexisNexisFixtures.ddp_success_response_json }

      it 'is a successful result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to be_empty
      end
    end

    context 'when the response raises an exception' do
      let(:response_body) { '' }

      it 'returns an exception result' do
        error = RuntimeError.new('hi')

        expect(NewRelic::Agent).to receive(:notice_error).with(error)

        stub_request(
          :post,
          verification_request.url,
        ).to_raise(error)

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to be_empty
        expect(result.exception).to eq(error)
      end
    end

    context 'when the review status has an unexpected value' do
      let(:response_body) { LexisNexisFixtures.ddp_unexpected_review_status_response_json }

      it 'returns an exception result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.exception.inspect).to include(LexisNexisFixtures.ddp_unexpected_review_status)
      end
    end
  end
end
