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
  let(:images_cropped) { false }
  let(:document_type) { 'DriversLicense' }
  let(:document_class_name) { 'Drivers License' }
  let(:back_image_required) { true }
  let(:passports_enabled) { false }
  let(:passport_requested) { false }

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
  let(:front_image) { DocAuthImageFixtures.document_front_image }
  let(:back_image) { DocAuthImageFixtures.document_back_image }
  let(:selfie_image) { DocAuthImageFixtures.selfie_image }
  let(:passport_image) { nil }
  let(:liveness_checking_required) { false }
  let(:subject) do
    described_class.new(
      config: config,
      front_image: front_image,
      back_image: back_image,
      passport_image: passport_image,
      image_source: image_source,
      images_cropped: images_cropped,
      user_uuid: applicant[:uuid],
      uuid_prefix: applicant[:uuid_prefix],
      selfie_image: selfie_image,
      liveness_checking_required: liveness_checking_required,
      document_type: document_type,
      passport_requested:,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
      .and_return(passports_enabled)
  end

  shared_examples 'a successful request' do
    it 'uploads the image and returns a successful result' do
      request_stub_liveness = stub_request(:post, full_url).with do |request|
        request_json = JSON.parse(request.body, symbolize_names: true)
        expect(request_json[:Document][:Back].present?).to eq(back_image_required)
        expect(request_json[:Document][:DocumentType]).to eq(document_type)
        request_json[:Document][:Selfie].present?
      end.to_return(body: response_body(liveness_checking_required), status: 201)
      request_stub = stub_request(:post, full_url).with do |request|
        request_json = JSON.parse(request.body, symbolize_names: true)
        expect(request_json[:Document][:Back].present?).to eq(back_image_required)
        expect(request_json[:Document][:DocumentType]).to eq(document_type)
        !request_json[:Document][:Selfie].present?
      end.to_return(body: response_body(liveness_checking_required), status: 201)

      response = subject.fetch
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      if liveness_checking_required
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
          request_json = JSON.parse(request.body, symbolize_names: true)
          expect(request_json[:Document][:Back].present?).to eq(back_image_required)
          expect(request_json[:Document][:DocumentType]).to eq(document_type)
          request_json[:Document][:Selfie].present?
        end.to_return(
          body: response_body_with_doc_auth_errors(liveness_checking_required),
          status: 201,
        )
        request_stub = stub_request(:post, full_url).with do |request|
          request_json = JSON.parse(request.body, symbolize_names: true)
          expect(request_json[:Document][:Back].present?).to eq(back_image_required)
          expect(request_json[:Document][:DocumentType]).to eq(document_type)
          !request_json[:Document][:Selfie].present?
        end.to_return(
          body: response_body_with_doc_auth_errors(liveness_checking_required),
          status: 201,
        )

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors.keys).to contain_exactly(:general, :front, :back, :hints)

        expect(response.errors[:general]).to contain_exactly(
          DocAuth::Errors::GENERAL_ERROR,
        )
        expect(response.errors[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
        expect(response.errors[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
        expect(response.errors[:hints]).to eq(true)
        expect(response.exception).to be_nil

        if liveness_checking_required
          expect(request_stub_liveness).to have_been_requested
          expect(response.selfie_check_performed?).to be(true)
        else
          expect(request_stub).to have_been_requested
          expect(response.selfie_check_performed?).to be(false)
        end
      end
    end
  end

  context 'when liveness checking is NOT required' do
    let(:liveness_checking_required) { false }

    context 'with non-cropped images' do
      it 'use cropping non-liveness workflow' do
        expect(subject.send(:workflow)).to eq(cropping_non_liveness_flow)
      end
      it_behaves_like 'a successful request'
    end

    context 'with cropped images' do
      let(:images_cropped) { true }
      it 'use non-cropping non-liveness workflow' do
        expect(subject.send(:workflow)).to eq(non_cropping_non_liveness_flow)
      end
      it_behaves_like 'a successful request'
    end
  end

  context 'when liveness checking is required' do
    let(:liveness_checking_required) { true }

    context 'with non-cropped images' do
      it 'use cropping liveness workflow' do
        expect(subject.send(:workflow)).to eq(cropping_liveness_flow)
      end

      it_behaves_like 'a successful request'
    end

    context 'with cropped images' do
      let(:images_cropped) { true }
      it 'use non-cropping liveness workflow' do
        expect(subject.send(:workflow)).to eq(non_cropping_liveness_flow)
      end
      it_behaves_like 'a successful request'
    end
  end

  context 'with a Passport document_type' do
    let(:document_type) { 'Passport' }
    let(:document_class_name) { 'Passport' }
    let(:back_image_required) { false }
    let(:passport_image) { DocAuthImageFixtures.document_passport_image }
    let(:passports_enabled) { true }
    let(:passport_requested) { true }

    it_behaves_like 'a successful request'
  end

  context 'with the wrong id type submitted' do
    context 'user requests DriversLicense but submits Passport' do
      let(:document_type) { 'DriversLicense' }
      let(:document_class_name) { 'Passport' }
      let(:front_image) { DocAuthImageFixtures.document_passport_image }
      let(:back_image) { DocAuthImageFixtures.document_passport_image }
      let(:passports_enabled) { true }
      let(:passport_requested) { false }

      it 'fails with an unexpected_id_type error' do
        stub_request(:post, full_url).with do |request|
          request_json = JSON.parse(request.body, symbolize_names: true)
          expect(request_json[:Document][:Back].present?).to eq(back_image_required)
          expect(request_json[:Document][:DocumentType]).to eq(document_type)
          !request_json[:Document][:Selfie].present?
        end.to_return(
          body: response_body_with_doc_auth_errors(liveness_checking_required),
          status: 201,
        )

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors)
          .to eq({ unexpected_id_type: I18n.t('doc_auth.errors.general.no_liveness') })
      end
    end

    context 'user requests Passport but submits DriversLicense' do
      let(:document_type) { 'Passport' }
      let(:document_class_name) { 'Drivers License' }
      let(:back_image_required) { false }
      let(:passport_image) { DocAuthImageFixtures.document_front_image }
      let(:passports_enabled) { true }
      let(:passport_requested) { true }

      it 'fails with an unexpected_id_type error' do
        stub_request(:post, full_url).with do |request|
          request_json = JSON.parse(request.body, symbolize_names: true)
          expect(request_json[:Document][:Back].present?).to eq(back_image_required)
          expect(request_json[:Document][:DocumentType]).to eq(document_type)
          !request_json[:Document][:Selfie].present?
        end.to_return(
          body: response_body_with_doc_auth_errors(liveness_checking_required),
          status: 201,
        )

        response = subject.fetch

        expect(response.success?).to eq(false)
        expect(response.errors)
          .to eq({ unexpected_id_type: I18n.t('doc_auth.errors.general.no_liveness') })
      end
    end
  end

  context 'with non 200 http status code' do
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
    it 'returns needed information including workflow' do
      expect(subject.request_context).to include(
        workflow: an_instance_of(String),
      )
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
          {
            Group: 'IDAUTH_FIELD_DATA',
            Name: 'Fields_DocumentClassName',
            Values: [
              {
                Value: document_class_name,
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
      TransactionStatus: 'failed',
    },
    Products: [
      {
        ProductType: 'TrueID',
        ProductStatus: 'fail',
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
          {
            Group: 'IDAUTH_FIELD_DATA',
            Name: 'Fields_DocumentClassName',
            Values: [
              {
                Value: document_class_name,
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
