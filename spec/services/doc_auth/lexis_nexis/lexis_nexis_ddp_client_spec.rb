require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::LexisNexisDdpClient do
  let(:front_image) { 'front_image_data' }
  let(:back_image) { 'back_image_data' }
  let(:selfie_image) { 'selfie_image_data' }
  let(:passport_image) { 'passport_image_data' }
  let(:liveness_checking_required) { false }
  let(:passport_requested) { false }
  let(:document_type_requested) { DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE }
  let(:applicant) do
    {
      first_name: 'JANE',
      middle_name: 'M',
      last_name: 'DOE',
      dob: '1980-01-01',
      address1: '123 Fake St',
      address2: 'Apt 2',
      city: 'Anytown',
      state: 'ZZ',
      zipcode: '00000',
      ssn: '900-00-0000',
      email: 'person.name@email.test',
    }
  end

  let(:attrs) do
    {
      api_key: 'test_api_key',
      base_url: 'https://example.com',
      org_id: 'test_org_id',
    }
  end

  subject { described_class.new(attrs) }

  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_liveness_policy)
      .and_return('test_liveness_policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_noliveness_policy)
      .and_return('test_noliveness_policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_timeout)
      .and_return(30.0)
  end

  describe '#post_images' do
    let(:response_body) do
      {
        'request_id' => 'test_request_id',
        'request_result' => 'success',
        'review_status' => 'pass',
        'account_lex_id' => 'test_lex_id',
        'session_id' => 'test_session_id',
      }
    end

    before do
      stub_request(:post, 'https://example.com/authentication/v1/trueid/')
        .to_return(status: 200, body: response_body.to_json)
    end

    it 'sends a request and returns a DdpResult' do
      result = subject.post_images(
        front_image: front_image,
        back_image: back_image,
        document_type_requested: document_type_requested,
        passport_requested: passport_requested,
        liveness_checking_required: liveness_checking_required,
        applicant: applicant,
      )

      expect(result).to be_a(Proofing::DdpResult)
      expect(result.success).to eq(true)
      expect(result.transaction_id).to eq('test_request_id')
      expect(result.review_status).to eq('pass')
    end

    context 'when liveness checking is required' do
      it 'includes selfie image in the request body' do
        subject.post_images(
          front_image: front_image,
          back_image: back_image,
          selfie_image: selfie_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: true,
        )

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['trueid.selfie'] == Base64.strict_encode64(selfie_image) &&
              body['policy'] == 'test_liveness_policy'
          }
      end
    end

    context 'when liveness checking is not required' do
      it 'uses the noliveness policy' do
        subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: false,
        )

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['policy'] == 'test_noliveness_policy'
          }
      end
    end

    context 'when document type is passport' do
      let(:document_type_requested) { DocAuth::LexisNexis::DocumentTypes::PASSPORT }

      it 'uses passport image as front and excludes back image' do
        subject.post_images(
          front_image: front_image,
          back_image: back_image,
          passport_image: passport_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['trueid.white_front'] == Base64.strict_encode64(passport_image) &&
              body['trueid.white_back'] == ''
          }
      end
    end

    context 'when the request fails with an exception' do
      before do
        stub_request(:post, 'https://example.com/authentication/v1/trueid/')
          .to_raise(Faraday::ConnectionFailed.new('connection failed'))
      end

      it 'returns a failed DdpResult with exception' do
        result = subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_present
      end
    end

    context 'when review status is unexpected' do
      let(:response_body) do
        {
          'request_id' => 'test_request_id',
          'request_result' => 'success',
          'review_status' => 'unexpected_status',
          'account_lex_id' => 'test_lex_id',
          'session_id' => 'test_session_id',
        }
      end

      it 'raises an error and returns failed result' do
        result = subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_present
      end
    end

    context 'when review status is review' do
      let(:response_body) do
        {
          'request_id' => 'test_request_id',
          'request_result' => 'success',
          'review_status' => 'review',
          'account_lex_id' => 'test_lex_id',
          'session_id' => 'test_session_id',
        }
      end

      it 'returns a failed result with review_status error' do
        result = subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(result.success).to eq(false)
        expect(result.review_status).to eq('review')
        expect(result.errors).to include(:review_status)
      end
    end

    context 'when review status is reject' do
      let(:response_body) do
        {
          'request_id' => 'test_request_id',
          'request_result' => 'success',
          'review_status' => 'reject',
          'account_lex_id' => 'test_lex_id',
          'session_id' => 'test_session_id',
        }
      end

      it 'returns a failed result with review_status error' do
        result = subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(result.success).to eq(false)
        expect(result.review_status).to eq('reject')
        expect(result.errors).to include(:review_status)
      end
    end

    context 'when request_result is not success' do
      let(:response_body) do
        {
          'request_id' => 'test_request_id',
          'request_result' => 'error',
          'review_status' => 'pass',
          'account_lex_id' => 'test_lex_id',
          'session_id' => 'test_session_id',
        }
      end

      it 'returns a failed result with request_result error' do
        result = subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(result.success).to eq(false)
        expect(result.errors).to include(:request_result)
      end
    end

    context 'when required images are missing' do
      it 'raises ArgumentError when front_image is nil for drivers license' do
        result = subject.post_images(
          front_image: nil,
          back_image: back_image,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to include('front_image is required')
      end

      it 'raises ArgumentError when back_image is nil for drivers license' do
        result = subject.post_images(
          front_image: front_image,
          back_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to eq('back_image is required')
      end

      it 'raises ArgumentError when passport_image is nil for passport' do
        result = subject.post_images(
          front_image: front_image,
          back_image: back_image,
          passport_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::PASSPORT,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to include('passport_image is required')
      end

      it 'raises ArgumentError when selfie_image is nil with liveness checking' do
        result = subject.post_images(
          front_image: front_image,
          back_image: back_image,
          selfie_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          passport_requested: passport_requested,
          liveness_checking_required: true,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to include('selfie_image is required')
      end
    end
  end

  describe 'request headers' do
    before do
      stub_request(:post, 'https://example.com/authentication/v1/trueid/')
        .to_return(
          status: 200,
          body: { 'request_result' => 'success', 'review_status' => 'pass' }.to_json,
        )
    end

    it 'includes Content-Type, x-org-id, and x-api-key headers' do
      subject.post_images(
        front_image: front_image,
        back_image: back_image,
        document_type_requested: document_type_requested,
        passport_requested: passport_requested,
        liveness_checking_required: liveness_checking_required,
      )

      expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
        .with(headers: {
          'Content-Type' => 'application/json',
          'x-org-id' => 'test_org_id',
          'x-api-key' => 'test_api_key',
        })
    end
  end

  describe 'request body' do
    before do
      stub_request(:post, 'https://example.com/authentication/v1/trueid/')
        .to_return(
          status: 200,
          body: { 'request_result' => 'success', 'review_status' => 'pass' }.to_json,
        )
    end

    it 'includes images with correct key format' do
      subject.post_images(
        front_image: front_image,
        back_image: back_image,
        document_type_requested: document_type_requested,
        passport_requested: passport_requested,
        liveness_checking_required: liveness_checking_required,
      )

      expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
        .with { |req|
          body = JSON.parse(req.body)
          body['trueid.white_front'] == Base64.strict_encode64(front_image) &&
            body['trueid.white_back'] == Base64.strict_encode64(back_image)
        }
    end

    it 'includes applicant personal info' do
      subject.post_images(
        front_image: front_image,
        back_image: back_image,
        document_type_requested: document_type_requested,
        passport_requested: passport_requested,
        liveness_checking_required: liveness_checking_required,
        applicant: applicant,
      )

      expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
        .with { |req|
          body = JSON.parse(req.body)
          body['account_first_name'] == 'JANE' &&
            body['account_middle_name'] == 'M' &&
            body['account_last_name'] == 'DOE' &&
            body['account_date_of_birth'] == '19800101' &&
            body['account_address_street1'] == '123 Fake St' &&
            body['account_address_street2'] == 'Apt 2' &&
            body['account_address_city'] == 'Anytown' &&
            body['account_address_state'] == 'ZZ' &&
            body['account_address_zip'] == '00000' &&
            body['account_address_country'] == 'us' &&
            body['national_id_number'] == '900000000' &&
            body['national_id_type'] == 'US_SSN' &&
            body['account_email'] == 'person.name@email.test'
        }
    end

    context 'with empty applicant' do
      it 'uses empty string defaults for all fields' do
        subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
          applicant: {},
        )

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['account_first_name'] == '' &&
              body['account_last_name'] == '' &&
              body['account_date_of_birth'] == '' &&
              body['account_address_street1'] == '' &&
              body['account_address_country'] == '' &&
              body['national_id_number'] == '' &&
              body['national_id_type'] == ''
          }
      end
    end

    context 'with dob as Date object' do
      it 'formats the date correctly' do
        subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
          applicant: { dob: Date.new(1980, 1, 1) },
        )

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['account_date_of_birth'] == '19800101'
          }
      end
    end

    context 'with partial address (only city)' do
      it 'sets country to us when any address field is present' do
        subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
          applicant: { city: 'Anytown' },
        )

        expect(WebMock).to have_requested(:post, 'https://example.com/authentication/v1/trueid/')
          .with { |req|
            body = JSON.parse(req.body)
            body['account_address_city'] == 'Anytown' &&
              body['account_address_country'] == 'us'
          }
      end
    end
  end

  describe 'error handling' do
    context 'when an exception occurs' do
      before do
        stub_request(:post, 'https://example.com/authentication/v1/trueid/')
          .to_raise(Faraday::ConnectionFailed.new('connection failed'))
      end

      it 'notifies NewRelic of the error' do
        expect(NewRelic::Agent).to receive(:notice_error)
          .with(instance_of(Proofing::LexisNexis::RequestError))

        subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
        )
      end
    end

    context 'with invalid dob format' do
      before do
        stub_request(:post, 'https://example.com/authentication/v1/trueid/')
          .to_return(
            status: 200,
            body: { 'request_result' => 'success', 'review_status' => 'pass' }.to_json,
          )
      end

      it 'returns failed result when dob cannot be parsed' do
        result = subject.post_images(
          front_image: front_image,
          back_image: back_image,
          document_type_requested: document_type_requested,
          passport_requested: passport_requested,
          liveness_checking_required: liveness_checking_required,
          applicant: { dob: 'not-a-date' },
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(Date::Error)
      end
    end
  end
end
