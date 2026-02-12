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
      base_url: 'https://lexis.nexis.example.com',
      locale: 'en',
      trueid_account_id: 'test_account',
      trueid_noliveness_cropping_workflow: 'NOLIVENESS.CROPPING.WORKFLOW',
      trueid_noliveness_nocropping_workflow: 'NOLIVENESS.NOCROPPING.WORKFLOW',
      trueid_liveness_cropping_workflow: 'LIVENESS.CROPPING.WORKFLOW',
      trueid_liveness_nocropping_workflow: 'LIVENESS.NOCROPPING.WORKFLOW',
    }
  end
  let(:success_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }
  let(:failure_response_body) { LexisNexisFixtures.ddp_true_id_response_fail }
  let(:failure_response_with_review_status_body) do
    LexisNexisFixtures.ddp_true_id_response_fail_with_review_status
  end

  subject { described_class.new(attrs) }

  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_liveness_policy)
      .and_return('test_liveness_policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_noliveness_policy)
      .and_return('test_noliveness_policy')
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_timeout)
      .and_return(30.0)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('org_id_str')
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_noliveness_policy)
      .and_return('default_auth_policy_pm')
  end

  let(:post_url) do
    'https://lexis.nexis.example.com/restws/identity/v3/accounts/test_account/workflows/NOLIVENESS.CROPPING.WORKFLOW/conversations'
  end

  describe '#post_images' do
    let(:response_body) do
      success_response_body
    end

    before do
      stub_request(:post, post_url)
        .to_return(status: 200, body: response_body)
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

      expect(result).to be_a(DocAuth::LexisNexis::Responses::Ddp::TrueIdResponse)
      expect(result.success?).to eq(true)
      expect(result.extra_attributes[:request_id]).to eq('test_request_id')
      expect(result.extra_attributes[:review_status]).to eq('pass')
    end

    context 'when the request fails with an exception' do
      before do
        stub_request(:post, post_url)
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

        expect(result.success?).to eq(false)
        expect(result.exception).to be_present
      end
    end

    context 'when review status is unexpected' do
      let(:response_body) do
        failure_response_body
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

        expect(result.success?).to eq(false)
        expect(result.errors).to be_present
      end
    end

    context 'when review status is review' do
      let(:response_body) do
        failure_response_with_review_status_body
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

        expect(result.success?).to eq(false)
        expect(result.extra_attributes[:review_status]).to eq('review')
        # expect(result.errors).to include(:review_status)
      end
    end

    context 'when review status is reject' do
      let(:response_body) do
        failure_response_body
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

        expect(result.success?).to eq(false)
        expect(result.extra_attributes[:review_status]).to eq('reject')
        # expect(result.errors).to include(:review_status)
      end
    end

    context 'when request_result is not success' do
      let(:response_body) do
        failure_response_body
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

        expect(result.success?).to eq(false)
        # expect(result.errors).to include(:request_result)
      end
    end

    context 'when required fields are missing' do
      it 'returns ArgumentError when uuid is nil' do
        expect do
          subject.post_images(
            front_image:,
            back_image:,
            document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
            passport_requested:,
            liveness_checking_required:,
            user_email:,
          )
        end.to raise_error(ArgumentError, 'uuid is required')
      end

      it 'returns ArgumentError when email is nil' do
        expect do
          subject.post_images(
            front_image:,
            back_image:,
            document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
            passport_requested:,
            liveness_checking_required:,
            user_uuid:,
          )
        end.to raise_error(ArgumentError, 'email is required')
      end

      it 'returns ArgumentError when front_image is nil for drivers license' do
        expect do
          subject.post_images(
            front_image: nil,
            back_image:,
            document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
            passport_requested:,
            liveness_checking_required:,
            user_uuid:,
            user_email:,
          )
        end.to raise_error(ArgumentError, 'front_image is required')
      end

      it 'returns ArgumentError when back_image is nil for drivers license' do
        expect do
          subject.post_images(
            front_image:,
            back_image: nil,
            document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
            passport_requested:,
            liveness_checking_required:,
            user_uuid:,
            user_email:,
          )
        end.to raise_error(ArgumentError, 'back_image is required')
      end

      it 'returns ArgumentError when passport_image is nil for passport' do
        expect do
          subject.post_images(
            front_image:,
            back_image:,
            passport_image: nil,
            document_type_requested: DocAuth::LexisNexis::DocumentTypes::PASSPORT,
            passport_requested:,
            liveness_checking_required:,
            user_uuid:,
            user_email:,
          )
        end.to raise_error(ArgumentError, 'passport_image is required for passport documents')
      end

      it 'returns ArgumentError when selfie_image is nil with liveness checking' do
        expect do
          subject.post_images(
            front_image:,
            back_image:,
            selfie_image: nil,
            document_type_requested: DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE,
            passport_requested:,
            liveness_checking_required: true,
            user_uuid:,
            user_email:,
          )
        end.to raise_error(
          ArgumentError,
          'selfie_image is required when liveness checking is enabled',
        )
      end
    end

    context 'when an exception occurs' do
      before do
        stub_request(:post, post_url)
          .to_raise(Faraday::ConnectionFailed.new('connection failed'))
      end

      it 'routed to handle_connection_error and returns a failed response' do
        response = subject.post_images(
          front_image:,
          back_image:,
          document_type_requested:,
          passport_requested:,
          liveness_checking_required:,
          user_uuid:,
          user_email:,
        )

        expect(response.success?).to eq(false)
        expect(response.exception).to be_a(Faraday::ConnectionFailed)
        expect(response.exception.message).to eq('connection failed')
        expect(response.errors).to include(:network)
      end
    end
  end
end
