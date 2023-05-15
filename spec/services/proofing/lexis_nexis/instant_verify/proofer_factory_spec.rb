# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Proofing::LexisNexis::InstantVerify::ProoferFactory do
  let(:logging_user_email) do
    'test.user+dav3@example.com'
  end

  let(:non_logging_user_email) do
    'test@example.com'
  end

  let(:applicant) do
    {
      uuid_prefix: '0987',
      uuid: '1234-abcd',
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123456789',
      dob: '01/01/1980',
      address1: '123 Main St',
      address2: 'Ste 3',
      city: 'Baton Rouge',
      state: 'LA',
      zipcode: '70802-12345',
    }
  end

  let(:resolution_context) do
    Proofing::Resolution::ResolutionContext.new(pii: applicant, user_email: logging_user_email)
  end
  let(:subject) { described_class.new(resolution_context) }

  context 'when proofer_mock_fallback disabled' do
    before(:each) do
      # rubocop:disable Layout/LineLength
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
      allow(IdentityConfig.store).to receive(:in_person_verify_test_logging_enabled).and_return(true)
      # rubocop:enable Layout/LineLength
    end
    it 'when user email is configured for logging, it returns the logging proofer' do
      resolution_context.user_email = logging_user_email
      proofer = subject.get_proofer(address_type: 'residential_address')
      expect(proofer).to be_a Proofing::LexisNexis::InstantVerify::LoggingProofer
    end

    it 'when user email is not configured for logging, it returns the non-logging proofer' do
      resolution_context.user_email = non_logging_user_email
      proofer = subject.get_proofer(address_type: 'residential_address')
      expect(proofer).to be_a Proofing::LexisNexis::InstantVerify::Proofer
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
      proofer = subject.get_proofer(address_type: 'id_address')
      expect(proofer).to be_a Proofing::Mock::ResolutionMockClient
    end

    it 'when user email is not configured for logging, it returns the mock' do
      # rubocop:disable Layout/LineLength
      allow(IdentityConfig.store).to receive(:in_person_verify_test_logging_enabled).and_return(true)
      # rubocop:enable Layout/LineLength

      resolution_context.user_email = non_logging_user_email
      proofer = subject.get_proofer(address_type: 'id_address')
      expect(proofer).to be_a Proofing::Mock::ResolutionMockClient
    end
  end
end
