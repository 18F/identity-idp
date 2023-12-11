require 'rails_helper'

RSpec.describe Idv::LexisnexisInstantVerify, :controller do
  controller ApplicationController do
    include Idv::LexisnexisInstantVerify

    def index; end
  end

  let(:session_uuid) { SecureRandom.uuid }

  subject(:variables) { controller.workflow_ab_testing_variables }

  before do
    allow(controller).to receive(:document_capture_session_uuid).
      and_return(session_uuid)
  end

  context 'with lexisnexis instant verify workflow A/B testing disabled' do
    let(:session_uuid) { SecureRandom.uuid }

    before do
      allow(IdentityConfig.store).
        to receive(:lexisnexis_instant_verify_workflow_ab_testing_enabled).
        and_return(false)
    end

    context 'and A/B test specifies the older acuant version' do
      before do
        stub_const(
          'AbTests::LEXISNEXIS_INSTANT_VERIFY_WORKFLOW',
          FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => 0) },
        )
      end

      it 'passes correct variables and acuant version when older is specified' do
        expect(variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(false)
        expect(variables[:use_alternate_sdk]).to eq(false)
        expect(variables[:acuant_version]).to eq(default_sdk_version)
      end
    end
  end

  context 'with acuant sdk upgrade A/B testing enabled' do
    before do
      allow(IdentityConfig.store).
        to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
        and_return(true)
    end

    context 'and A/B test specifies the newer acuant version' do
      before do
        stub_const(
          'AbTests::ACUANT_SDK',
          FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => :use_alternate_sdk) },
        )
      end

      it 'passes correct variables and acuant version when newer is specified' do
        expect(variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(true)
        expect(variables[:use_alternate_sdk]).to eq(true)
        expect(variables[:acuant_version]).to eq(alternate_sdk_version)
      end
    end

    context 'and A/B test specifies the older acuant version' do
      before do
        stub_const(
          'AbTests::ACUANT_SDK',
          FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => 0) },
        )
      end

      it 'passes correct variables and acuant version when older is specified' do
        expect(variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(true)
        expect(variables[:use_alternate_sdk]).to eq(false)
        expect(variables[:acuant_version]).to eq(default_sdk_version)
      end
    end
  end

  describe '#override_csp_to_allow_acuant' do
    it 'sets the headers for the document capture step' do
      get :index, params: { step: 'document_capture' }

      csp = response.request.content_security_policy
      expect(csp.script_src).to include("'unsafe-eval'")
      expect(csp.style_src).to include("'unsafe-inline'")
      expect(csp.img_src).to include('blob:')
    end
  end
end
