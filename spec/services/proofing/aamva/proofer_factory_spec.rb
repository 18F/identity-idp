# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Proofing::Aamva::ProoferFactory do
  let(:aamva_applicant) do
    Aamva::Applicant.from_proofer_applicant(OpenStruct.new(state_id_data))
  end

  let(:logging_user_email) do
    'test.user+dav3@example.com'
  end

  let(:non_logging_user_email) do
    'test@example.com'
  end

  let(:state_id_data) do
    {
      state_id_number: '1234567890',
      state_id_jurisdiction: 'VA',
      state_id_type: 'drivers_license',
    }
  end

  let(:resolution_context) do
    Proofing::Resolution::ResolutionContext.new(pii: state_id_data, user_email: logging_user_email)
  end
  subject do
    described_class.new(resolution_context)
  end

  context 'when proofer_mock_fallback disabled' do
    before(:each) do
      # rubocop:disable Layout/LineLength
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
      allow(IdentityConfig.store).to receive(:in_person_verify_test_logging_enabled).and_return(true)
      # rubocop:enable Layout/LineLength
    end
    it 'when user email is configured for logging, it returns the logging proofer' do
      resolution_context.user_email = logging_user_email
      proofer = subject.get_proofer
      expect(proofer).to be_a Proofing::Aamva::LoggingProofer
    end
    it 'when user email is not configured for logging, it returns the non-logging proofer' do
      resolution_context.user_email = non_logging_user_email
      proofer = subject.get_proofer
      expect(proofer).to be_a Proofing::Aamva::Proofer
    end
  end

  context 'when proofer_mock_fallback enabled' do
    before(:each) do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(true)
    end
    it 'when user email is configured for logging, it returns the mock' do
      # rubocop:disable Layout/LineLength
      allow(IdentityConfig.store).to receive(:in_person_verify_test_logging_enabled).and_return(true)
      # rubocop:enable Layout/LineLength

      resolution_context.user_email = logging_user_email
      proofer = subject.get_proofer
      expect(proofer).to be_a Proofing::Mock::StateIdMockClient
    end

    it 'when user email is not configured for logging, it returns the mock' do
      # rubocop:disable Layout/LineLength
      allow(IdentityConfig.store).to receive(:in_person_verify_test_logging_enabled).and_return(true)
      # rubocop:enable Layout/LineLength

      resolution_context.user_email = non_logging_user_email
      proofer = subject.get_proofer
      expect(proofer).to be_a Proofing::Mock::StateIdMockClient
    end
  end
end
