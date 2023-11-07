require 'rails_helper'

RSpec.describe Proofing::Aamva::SoapErrorHandler do
  let(:response_body) { AamvaFixtures.soap_fault_response }

  subject do
    http_response = Faraday::Response.new(status: 200, response_body:)
    described_class.new(http_response)
  end

  describe 'error_present?' do
    context 'when an error is present' do
      it { expect(subject.error_present?).to eq(true) }
    end

    context 'when an error is not present' do
      let(:response_body) { AamvaFixtures.authentication_token_response }

      it { expect(subject.error_present?).to eq(false) }
    end
  end

  describe 'error_message' do
    context 'when there is no error' do
      let(:response_body) { AamvaFixtures.authentication_token_response }

      it { expect(subject.error_message).to eq(nil) }
    end

    context 'when there is an error' do
      it 'contains relevant parts of the error message' do
        expect(subject.error_message).to include('A FooBar error occurred')

        expect(subject.error_message).to include('ExceptionId: 0047')
        expect(subject.error_message).to include(
          'ExceptionText: MVA did not respond in a timely fashion',
        )
        expect(subject.error_message).to include('ExceptionTypeCode: I')

        expect(subject.error_message).to include('ExceptionId: 0048')
        expect(subject.error_message).to include(
          'Servers are experiencing higher than regular traffic',
        )
        expect(subject.error_message).to include('ExceptionTypeCode: J')
      end
    end

    context 'when there is an error without a ProgramException section' do
      let(:response_body) do
        delete_xml_at_xpath(
          AamvaFixtures.soap_fault_response,
          '//ProgramExceptions',
        )
      end

      it { expect(subject.error_message).to eq('A FooBar error occurred') }
    end

    context 'when there is an error without a message' do
      let(:response_body) do
        delete_xml_at_xpath(
          AamvaFixtures.soap_fault_response,
          '//s:Reason',
        )
      end

      it { expect(subject.error_message).to include('A SOAP error occurred') }
    end
  end
end
