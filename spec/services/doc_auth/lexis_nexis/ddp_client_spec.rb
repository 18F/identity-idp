require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::DdpClient do
  let(:front_image) { 'front_image_data' }
  let(:back_image) { 'back_image_data' }
  let(:selfie_image) { 'selfie_image_data' }
  let(:passport_image) { 'passport_image_data' }
  let(:liveness_checking_required) { false }
  let(:passport_requested) { false }
  let(:document_type_requested) { DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE }
  let(:user_uuid) { 'test_uuid' }
  let(:user_email) { 'person.name@email.test' }

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
        front_image:,
        back_image:,
        document_type_requested:,
        passport_requested:,
        liveness_checking_required:,
        user_uuid:,
        user_email:,
      )

      expect(result).to be_a(Proofing::DdpResult)
      expect(result.success).to eq(true)
      expect(result.transaction_id).to eq('test_request_id')
      expect(result.review_status).to eq('pass')
    end

    context 'when the request fails with an exception' do
      before do
        stub_request(:post, 'https://example.com/authentication/v1/trueid/')
          .to_raise(Faraday::ConnectionFailed.new('connection failed'))
      end

      it 'returns a failed DdpResult with exception' do
        result = subject.post_images(
          front_image:,
          back_image:,
          document_type_requested:,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
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
          front_image:,
          back_image:,
          document_type_requested:,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
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
          front_image:,
          back_image:,
          document_type_requested:,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
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
          front_image:,
          back_image:,
          document_type_requested:,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
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
          front_image:,
          back_image:,
          document_type_requested:,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
        )

        expect(result.success).to eq(false)
        expect(result.errors).to include(:request_result)
      end
    end

    context 'when required fields are missing' do
      it 'returns ArgumentError when uuid is nil' do
        result = subject.post_images(
          front_image:,
          back_image:,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          passport_requested:,
          liveness_checking_required:,
          user_email:,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to include('uuid is required')
      end

      it 'returns ArgumentError when email is nil' do
        result = subject.post_images(
          front_image:,
          back_image:,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to include('email is required')
      end

      it 'returns ArgumentError when front_image is nil for drivers license' do
        result = subject.post_images(
          front_image: nil,
          back_image:,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to include('front_image is required')
      end

      it 'returns ArgumentError when back_image is nil for drivers license' do
        result = subject.post_images(
          front_image:,
          back_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to eq('back_image is required')
      end

      it 'returns ArgumentError when passport_image is nil for passport' do
        result = subject.post_images(
          front_image:,
          back_image:,
          passport_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::PASSPORT,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to include('passport_image is required')
      end

      it 'returns ArgumentError when selfie_image is nil with liveness checking' do
        result = subject.post_images(
          front_image:,
          back_image:,
          selfie_image: nil,
          document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
          passport_requested:,
          liveness_checking_required: true,
          user_uuid:,
          user_email:,
        )

        expect(result.success).to eq(false)
        expect(result.exception).to be_a(ArgumentError)
        expect(result.exception.message).to include('selfie_image is required')
      end
    end

    context 'when an exception occurs' do
      before do
        stub_request(:post, 'https://example.com/authentication/v1/trueid/')
          .to_raise(Faraday::ConnectionFailed.new('connection failed'))
      end

      it 'notifies NewRelic of the error' do
        expect(NewRelic::Agent).to receive(:notice_error)
          .with(instance_of(Proofing::LexisNexis::RequestError))

        subject.post_images(
          front_image:,
          back_image:,
          document_type_requested:,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
        )
      end
    end
  end
end
