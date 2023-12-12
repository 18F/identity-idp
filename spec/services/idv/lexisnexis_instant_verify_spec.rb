require 'rails_helper'

RSpec.describe Idv::LexisnexisInstantVerify do
  let(:session_uuid) { SecureRandom.uuid }
  let(:default_workflow) { 'legacy_workflow' }
  let(:alternate_workflow) { 'equitable_workflow' }
  let(:ab_testing_enabled) { false }

  subject { Idv::LexisnexisInstantVerify.new(session_uuid) }

  before do
    allow(IdentityConfig.store).
      to receive(:lexisnexis_instant_verify_workflow_ab_testing_enabled).
      and_return(ab_testing_enabled)
    allow(IdentityConfig.store).
      to receive(:lexisnexis_instant_verify_workflow_ab_testing_percent).
      and_return(5)
    allow(IdentityConfig.store).
      to receive(:lexisnexis_instant_verify_workflow).
      and_return(default_workflow)
    allow(IdentityConfig.store).
      to receive(:lexisnexis_instant_verify_workflow_alternate).
      and_return(alternate_workflow)
  end

  context 'with lexisnexis instant verify workflow A/B testing disabled' do
    let(:ab_testing_enabled) { false }

    it 'returns correct variables' do
      variables = subject.workflow_ab_testing_variables

      expect(variables[:ab_testing_enabled]).to eq(false)
      expect(variables[:use_alternate_workflow]).to eq(false)
      expect(variables[:instant_verify_workflow]).to eq(default_workflow)
    end
  end

  context 'with lexisnexis instant verify workflow A/B testing enabled' do
    let(:ab_testing_enabled) { true }

    context 'and A/B test specifies the alternate workflow' do
      before do
        stub_const(
          'AbTests::LEXISNEXIS_INSTANT_VERIFY_WORKFLOW',
          FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => :use_alternate_workflow) },
        )
      end

      it 'returns correct variables' do
        variables = subject.workflow_ab_testing_variables

        expect(variables[:ab_testing_enabled]).to eq(true)
        expect(variables[:use_alternate_workflow]).to eq(true)
        expect(variables[:instant_verify_workflow]).to eq(alternate_workflow)
      end
    end

    context 'and A/B test specifies the default workflow' do
      before do
        stub_const(
          'AbTests::LEXISNEXIS_INSTANT_VERIFY_WORKFLOW',
          FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => 0) },
        )
      end

      it 'returns correct variables' do
        variables = subject.workflow_ab_testing_variables

        expect(variables[:ab_testing_enabled]).to eq(true)
        expect(variables[:use_alternate_workflow]).to eq(false)
        expect(variables[:instant_verify_workflow]).to eq(default_workflow)
      end
    end
  end
end
