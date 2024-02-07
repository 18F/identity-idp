require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Requests::TrueIdRequest do
  let(:image_source) { nil }
  let(:account_id) { 'test_account' }
  let(:base_url) { 'https://lexis.nexis.example.com' }
  let(:workflow) { subject.send(:workflow) }
  let(:path) { "/restws/identity/v3/accounts/#{account_id}/workflows/#{workflow}/conversations" }
  let(:full_url) { base_url + path }
  let(:applicant) { { uuid: SecureRandom.uuid, uuid_prefix: '123' } }
  let(:non_cropping_non_liveness_flow) { 'test_workflow' }
  let(:cropping_non_liveness_flow) { 'test_workflow_cropping' }
  let(:non_cropping_liveness_flow) { 'test_workflow_liveness' }
  let(:cropping_liveness_flow) { 'test_workflow_liveness_cropping' }

  let(:config) do
    DocAuth::LexisNexis::Config.new(
      trueid_account_id: account_id,
      base_url: base_url,
      trueid_noliveness_cropping_workflow: cropping_non_liveness_flow,
      trueid_noliveness_nocropping_workflow: non_cropping_non_liveness_flow,
      trueid_liveness_cropping_workflow: cropping_liveness_flow,
      trueid_liveness_nocropping_workflow: non_cropping_liveness_flow,
    )
  end
  let(:selfie_image) { DocAuthImageFixtures.selfie_image }
  let(:liveness_checking_required) { false }
  let(:subject) do
    described_class.new(
      config: config,
      front_image: DocAuthImageFixtures.document_front_image,
      back_image: DocAuthImageFixtures.document_back_image,
      image_source: image_source,
      user_uuid: applicant[:uuid],
      uuid_prefix: applicant[:uuid_prefix],
      selfie_image: selfie_image,
      liveness_checking_required: liveness_checking_required,
    )
  end

  shared_examples 'a successful request' do
    it 'uploads the image and returns a successful result' do
      request_stub_liveness = stub_request(:post, full_url).with do |request|
        JSON.parse(request.body, symbolize_names: true)[:Document][:Selfie].present?
      end.to_return(body: response_body(include_liveness_expected), status: 201)
      request_stub = stub_request(:post, full_url).with do |request|
        !JSON.parse(request.body, symbolize_names: true)[:Document][:Selfie].present?
      end.to_return(body: response_body(include_liveness_expected), status: 201)

      response = subject.fetch

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      if include_liveness_expected
        expect(request_stub_liveness).to have_been_requested
        expect(response.selfie_check_performed?).to be(true)
      else
        expect(request_stub).to have_been_requested
        expect(response.selfie_check_performed?).to be(false)
      end
    end

    context 'fails document authentication' do
      it 'fails response with errors' do
        request_stub_liveness = stub_request(:post, full_url).with do |request|
          JSON.parse(request.body, symbolize_names: true)[:Document][:Selfie].present?
        end.to_return(
          body: response_body_with_doc_auth_errors(include_liveness_expected),
          status: 201,
        )
        request_stub = stub_request(:post, full_url).with do |request|
          !JSON.parse(request.body, symbolize_names: true)[:Document][:Selfie].present?
        end.to_return(
          body: response_body_with_doc_auth_errors(include_liveness_expected),
          status: 201,
        )

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors.keys).to contain_exactly(:general, :front, :back, :hints)
        expect(response.errors[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
        expect(response.errors[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
        expect(response.errors[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
        expect(response.errors[:hints]).to eq(true)
        expect(response.exception).to be_nil
        if include_liveness_expected
          expect(request_stub_liveness).to have_been_requested
          expect(response.selfie_check_performed?).to be(true)
        else
          expect(request_stub).to have_been_requested
          expect(response.selfie_check_performed?).to be(false)
        end
      end
    end

    def include_liveness_expected
      FeatureManagement.idv_allow_selfie_check? &&
        liveness_checking_required
    end
  end

  context 'with liveness_checking_enabled as false' do
    context 'when liveness checking is NOT required' do
      let(:liveness_checking_required) { false }
      context 'with acuant image source' do
        let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
        it_behaves_like 'a successful request'
        it 'uses non-cropping non-liveness workflow' do
          expect(subject.send(:workflow)).to eq(non_cropping_non_liveness_flow)
        end
        it 'does not include a nil selfie in the request body sent to TrueID' do
          body_as_json = subject.send(:body)
          body_as_hash = JSON.parse(body_as_json)
          expect(body_as_hash['Document']).not_to have_key('Selfie')
        end
      end
      context 'with unknown image source' do
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }
        it 'uses cropping non-liveness workflow' do
          expect(subject.send(:workflow)).to eq(cropping_non_liveness_flow)
        end
        it_behaves_like 'a successful request'
      end
    end

    context 'when liveness checking is required' do
      let(:liveness_checking_required) { true }
      context 'with acuant image source' do
        let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
        it 'uses non-cropping non-liveness workflow' do
          expect(subject.send(:workflow)).to eq(non_cropping_non_liveness_flow)
        end
        it_behaves_like 'a successful request'
      end
      context 'with unknown image source' do
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }
        it 'uses cropping non-liveness workflow' do
          expect(subject.send(:workflow)).to eq(cropping_non_liveness_flow)
        end
        it_behaves_like 'a successful request'
      end
    end
  end

  context 'with liveness_checking_enabled as true' do
    let(:selfie_check_allowed) { true }
    before do
      expect(FeatureManagement).to receive(:idv_allow_selfie_check?).at_least(:once).
        and_return(selfie_check_allowed)
    end

    context 'when liveness checking is NOT required' do
      let(:liveness_checking_required) { false }
      context 'with acuant image source' do
        let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
        it 'use non-cropping non-liveness workflow' do
          expect(subject.send(:workflow)).to eq(non_cropping_non_liveness_flow)
        end
        it_behaves_like 'a successful request'
      end
      context 'with unknown image source' do
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }
        it 'use cropping non-liveness workflow' do
          expect(subject.send(:workflow)).to eq(cropping_non_liveness_flow)
        end
        it_behaves_like 'a successful request'
      end
    end

    context 'when liveness checking is required' do
      let(:liveness_checking_required) { true }
      context 'with acuant image source' do
        let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
        it 'use non-cropping liveness workflow' do
          expect(subject.send(:workflow)).to eq(non_cropping_liveness_flow)
        end
        it_behaves_like 'a successful request'
      end
      context 'with unknown image source' do
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }
        it 'use cropping liveness workflow' do
          expect(subject.send(:workflow)).to eq(cropping_liveness_flow)
        end
        it_behaves_like 'a successful request'
      end

      context 'when hosted env is prod' do
        let(:selfie_check_allowed) { false }
        context 'with acuant image source' do
          let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
          it 'use non-cropping non-liveness workflow' do
            expect(subject.send(:workflow)).to eq(non_cropping_non_liveness_flow)
          end
          it_behaves_like 'a successful request'
        end
        context 'with unknown image source' do
          let(:image_source) { DocAuth::ImageSources::UNKNOWN }
          it 'use cropping non-liveness workflow' do
            expect(subject.send(:workflow)).to eq(cropping_non_liveness_flow)
          end
          it_behaves_like 'a successful request'
        end
      end
    end
  end

  context 'with non 200 http status code' do
    let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
    it 'is a network error with 5xx status' do
      stub_request(:post, full_url).to_return(body: '{}', status: 500)
      response = subject.fetch
      expect(response.network_error?).to eq(true)
    end
    it 'is a network error with non 5xx error' do
      stub_request(:post, full_url).to_return(body: '{}', status: 401)
      response = subject.fetch
      expect(response.network_error?).to eq(true)
    end
  end
  describe '#request_context' do
    it 'returns needed information' do
      # expect(subject.request_context).to eq(
      #
      # )
    end
  end
end

def response_body(include_liveness)
  {
    Status: {
      TransactionStatus: 'passed',
    },
    Products: [
      {
        ProductType: 'TrueID',
        ProductStatus: 'pass',
        ParameterDetails: [
          {
            Group: 'AUTHENTICATION_RESULT',
            Name: 'DocAuthResult',
            Values: [
              {
                Value: 'Passed',
              },
            ],
          },
          *(
            if include_liveness
              [
                Group: 'PORTRAIT_MATCH_RESULT',
                Name: 'FaceMatchResult',
                Values: [{ Value: 'Pass' }],
              ]
            end
          ),
        ],
      },
    ],
  }.to_json
end

def response_body_with_doc_auth_errors(include_liveness)
  {
    Status: {
      TransactionStatus: 'passed',
    },
    Products: [
      {
        ProductType: 'TrueID',
        ProductStatus: 'pass',
        ParameterDetails: [
          {
            Group: 'AUTHENTICATION_RESULT',
            Name: 'DocAuthResult',
            Values: [
              {
                Value: 'Failed',
              },
            ],
          },
          *(
            if include_liveness
              [
                Group: 'PORTRAIT_MATCH_RESULT',
                Name: 'FaceMatchResult',
                Values: [{ Value: 'Pass' }],
              ]
            end
          ),
        ],
      },
    ],
  }.to_json
end
