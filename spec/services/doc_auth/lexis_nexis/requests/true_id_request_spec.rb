require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Requests::TrueIdRequest do
  let(:image_source) { nil }
  let(:account_id) { 'test_account' }
  let(:workflow) { nil }
  let(:base_url) { 'https://lexis.nexis.example.com' }
  let(:path) { "/restws/identity/v3/accounts/#{account_id}/workflows/#{workflow}/conversations" }
  let(:full_url) { base_url + path }
  let(:applicant) { { uuid: SecureRandom.uuid, uuid_prefix: '123' } }
  let(:config) do
    DocAuth::LexisNexis::Config.new(
      trueid_account_id: account_id,
      base_url: base_url,
      trueid_noliveness_cropping_workflow: 'test_workflow_cropping',
      trueid_noliveness_nocropping_workflow: 'test_workflow',
      trueid_liveness_cropping_workflow: 'test_workflow_liveness_cropping',
      trueid_liveness_nocropping_workflow: 'test_workflow_liveness',
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
      include_liveness = liveness_checking_required && !selfie_image.nil?
      request_stub_liveness = stub_request(:post, full_url).with do |request|
        JSON.parse(request.body, symbolize_names: true)[:Document][:Selfie].present?
      end.to_return(body: response_body(include_liveness), status: 201)
      request_stub = stub_request(:post, full_url).with do |request|
        !JSON.parse(request.body, symbolize_names: true)[:Document][:Selfie].present?
      end.to_return(body: response_body(include_liveness), status: 201)

      response = subject.fetch

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      if include_liveness
        expect(request_stub_liveness).to have_been_requested
      else
        expect(request_stub).to have_been_requested
      end
    end

    context 'fails document authentication' do
      it 'fails response with errors' do
        include_liveness = liveness_checking_required && !selfie_image.nil?
        request_stub_liveness = stub_request(:post, full_url).with do |request|
          JSON.parse(request.body, symbolize_names: true)[:Document][:Selfie].present?
        end.to_return(body: response_body_with_doc_auth_errors(include_liveness), status: 201)
        request_stub = stub_request(:post, full_url).with do |request|
          !JSON.parse(request.body, symbolize_names: true)[:Document][:Selfie].present?
        end.to_return(body: response_body_with_doc_auth_errors(include_liveness), status: 201)

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors.keys).to contain_exactly(:general, :front, :back, :hints)
        expect(response.errors[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
        expect(response.errors[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
        expect(response.errors[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
        expect(response.errors[:hints]).to eq(true)
        expect(response.exception).to be_nil
        if include_liveness
          expect(request_stub_liveness).to have_been_requested
        else
          expect(request_stub).to have_been_requested
        end
      end
    end
  end

  context 'with liveness_checking_enabled as false' do
    let(:liveness_checking_required) { false }
    context 'with acuant image source' do
      let(:workflow) { 'test_workflow' }
      let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
      it_behaves_like 'a successful request'

      it 'does not include a nil selfie in the request body sent to TrueID' do
        body_as_json = subject.send(:body)
        body_as_hash = JSON.parse(body_as_json)
        expect(body_as_hash['Document']).not_to have_key('Selfie')
      end
    end
    context 'with unknown image source' do
      let(:workflow) { 'test_workflow_cropping' }
      let(:image_source) { DocAuth::ImageSources::UNKNOWN }

      it_behaves_like 'a successful request'
    end
  end

  context 'with liveness_checking_enabled as true' do
    let(:liveness_checking_required) { true }
    context 'with acuant image source' do
      let(:workflow) { 'test_workflow_liveness' }
      let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }

      it_behaves_like 'a successful request'
    end
    context 'with unknown image source' do
      let(:workflow) { 'test_workflow_liveness_cropping' }
      let(:image_source) { DocAuth::ImageSources::UNKNOWN }

      it_behaves_like 'a successful request'
    end
  end

  context 'with non 200 http status code' do
    let(:workflow) { 'test_workflow' }
    let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
    it 'is a network error with 5xx status' do
      stub_request(:post, full_url).to_return(body: '{}', status: 500)
      response = subject.fetch
      expect(response.network_error?).to eq(true)
    end
    it 'is not a network error with 440, 438, 439' do
      stub_request(:post, full_url).to_return(body: '{}', status: 443)
      response = subject.fetch
      expect(response.network_error?).to eq(true)
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
                Values: [{ Value: 'Success' }],
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
                Values: [{ Value: 'Success' }],
              ]
            end
          ),
        ],
      },
    ],
  }.to_json
end
