require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::LexisNexisClient do
  let(:images_cropped) { false }
  let(:workflow) { 'NOLIVENESS.CROPPING.WORKFLOW' }
  let(:image_upload_url) do
    URI.join(
      'https://lexis.nexis.example.com',
      "/restws/identity/v3/accounts/test_account/workflows/#{workflow}/conversations",
    )
  end

  subject(:client) do
    DocAuth::LexisNexis::LexisNexisClient.new(
      base_url: 'https://lexis.nexis.example.com',
      locale: 'en',
      trueid_account_id: 'test_account',
      trueid_noliveness_cropping_workflow: 'NOLIVENESS.CROPPING.WORKFLOW',
      trueid_noliveness_nocropping_workflow: 'NOLIVENESS.NOCROPPING.WORKFLOW',
      trueid_liveness_cropping_workflow: 'LIVENESS.CROPPING.WORKFLOW',
      trueid_liveness_nocropping_workflow: 'LIVENESS.NOCROPPING.WORKFLOW',
    )
  end
  let(:user) { create(:user) }
  let(:document_capture_session) { create(:document_capture_session, user:) }

  describe '#post_images' do
    before do
      stub_request(:post, image_upload_url).to_return(
        body: LexisNexisFixtures.true_id_response_success,
      )
    end

    context 'with cropped images' do
      let(:images_cropped) { true }
      let(:workflow) { 'NOLIVENESS.NOCROPPING.WORKFLOW' }

      it 'sends an upload image request for the front and back DL images' do
        result = client.post_images(
          user_uuid: document_capture_session.uuid,
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          images_cropped: images_cropped,
        )

        expect(result.success?).to eq(true)
        expect(result.class).to eq(DocAuth::LexisNexis::Responses::TrueIdResponse)
      end
    end

    context 'with non-cropped images' do
      let(:workflow) { 'NOLIVENESS.CROPPING.WORKFLOW' }

      it 'sends an upload image request for the front and back DL images' do
        result = client.post_images(
          user_uuid: document_capture_session.uuid,
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          images_cropped: images_cropped,
        )

        expect(result.success?).to eq(true)
        expect(result.class).to eq(DocAuth::LexisNexis::Responses::TrueIdResponse)
      end
    end

    context 'when the results return failure' do
      it 'returns a FormResponse with failure' do
        stub_request(:post, image_upload_url).to_return(
          body: LexisNexisFixtures.true_id_response_failure_no_liveness,
        )

        result = client.post_images(
          user_uuid: document_capture_session.uuid,
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          images_cropped: images_cropped,
        )

        expect(result.success?).to eq(false)
      end
    end
  end

  context 'when the request is not successful' do
    it 'returns a response with an exception' do
      stub_request(:post, image_upload_url).to_return(body: '', status: 500)

      result = client.post_images(
        user_uuid: document_capture_session.uuid,
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        images_cropped: images_cropped,
      )

      expect(result.success?).to eq(false)
      expect(result.errors).to eq(network: true)
      expect(result.exception.message).to eq(
        'DocAuth::LexisNexis::Requests::TrueIdRequest Unexpected HTTP response 500',
      )
    end
  end

  context 'when there is a networking error' do
    it 'returns a response with an exception' do
      stub_request(:post, image_upload_url).to_raise(Faraday::TimeoutError.new('Connection failed'))

      result = client.post_images(
        user_uuid: document_capture_session.uuid,
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        images_cropped: images_cropped,
      )

      expect(result.success?).to eq(false)
      expect(result.errors).to eq(network: true)
      expect(result.exception.message).to eq(
        'Connection failed',
      )
    end
  end

  context 'with selfie check enabled' do
    ## enable feature
    let(:workflow) { 'LIVENESS.CROPPING.WORKFLOW' }

    describe 'when success response returned' do
      before do
        stub_request(:post, image_upload_url).to_return(
          body: LexisNexisFixtures.true_id_response_success_with_liveness,
        )
      end
      it 'returns a successful response' do
        result = client.post_images(
          user_uuid: document_capture_session.uuid,
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          images_cropped: images_cropped,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_required: true,
        )
        expect(result.success?).to eq(true)
        expect(result.class).to eq(DocAuth::LexisNexis::Responses::TrueIdResponse)
        expect(result.doc_auth_success?).to eq(true)
        expect(result.selfie_live?).to eq(true)
        expect(result.selfie_quality_good?).to eq(true)
        expect(result.selfie_check_performed?).to eq(true)
      end
    end

    describe 'when selfie failure response returned' do
      before do
        stub_request(:post, image_upload_url).to_return(
          body: LexisNexisFixtures.true_id_response_failure_with_liveness,
        )
      end

      it 'returns a response indicate all failures' do
        result = client.post_images(
          user_uuid: document_capture_session.uuid,
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          images_cropped: images_cropped,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_required: true,
        )
        expect(result.success?).to eq(false)
        expect(result.class).to eq(DocAuth::LexisNexis::Responses::TrueIdResponse)
        expect(result.doc_auth_success?).to eq(false)
        result_hash = result.to_h
        expect(result_hash[:reference]).not_to be_nil
        expect(result_hash[:selfie_status]).to eq(:fail)
        expect(result.selfie_live?).to eq(true)
        expect(result.selfie_quality_good?).to eq(false)
        expect(result.selfie_check_performed?).to eq(true)
      end
    end

    describe 'when http request failed' do
      let(:status_code) { 1002 }
      let(:status_message) { 'The request sent by the client was syntactically incorrect.' }
      it 'return failed response with correct statuses' do
        stub_request(:post, image_upload_url)
          .to_return(
            body: {
              status: {
                code: status_code,
                message: status_message,
              },
            }.to_json,
            status: 401,
          )

        result = client.post_images(
          user_uuid: document_capture_session.uuid,
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          images_cropped: images_cropped,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_required: true,
        )

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(network: true)
        expect(result.exception.message).to eq(
          'DocAuth::LexisNexis::Requests::TrueIdRequest Unexpected HTTP response 401',
        )
        result_hash = result.to_h
        expect(result_hash[:vendor]).to eq('TrueID')
        expect(result_hash[:doc_auth_success]).to eq(false)
        expect(result_hash[:reference]).not_to be_nil
        expect(result_hash[:selfie_status]).to eq(:not_processed)
        expect(result_hash[:vendor_status_code]).to eq(status_code)
        expect(result_hash[:vendor_status_message]).to eq(status_message)
        expect(result.class).to eq(DocAuth::Response)
      end

      context 'when json is not returned in the body' do
        it 'return failed response with correct statuses' do
          stub_request(:post, image_upload_url)
            .to_return(
              body: 'not json',
              status: 401,
            )

          result = client.post_images(
            user_uuid: document_capture_session.uuid,
            front_image: DocAuthImageFixtures.document_front_image,
            back_image: DocAuthImageFixtures.document_back_image,
            images_cropped: images_cropped,
            selfie_image: DocAuthImageFixtures.selfie_image,
            liveness_checking_required: true,
          )

          expect(result.success?).to eq(false)
          expect(result.errors).to eq(network: true)
          expect(result.exception.message).to eq(
            'DocAuth::LexisNexis::Requests::TrueIdRequest Unexpected HTTP response 401',
          )
          result_hash = result.to_h
          expect(result_hash[:vendor]).to eq('TrueID')
          expect(result_hash[:doc_auth_success]).to eq(false)
          expect(result_hash[:reference]).not_to be_nil
          expect(result_hash[:selfie_status]).to eq(:not_processed)
          expect(result_hash[:vendor_status_code]).to be_nil
          expect(result_hash[:vendor_status_message]).to be_nil
          expect(result.class).to eq(DocAuth::Response)
        end
      end
    end
  end
end
