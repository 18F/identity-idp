require 'rails_helper'
require 'ostruct'

RSpec.describe Proofing::Aamva::Proofer do
  let(:aamva_applicant) do
    Aamva::Applicant.from_proofer_applicant(OpenStruct.new(state_id_data))
  end

  let(:state_id_data) do
    {
      state_id_number: '1234567890',
      state_id_jurisdiction: 'VA',
      state_id_type: 'drivers_license',
    }
  end

  let(:verification_results) do
    {
      state_id_number: true,
      dob: true,
      last_name: true,
      last_name_fuzzy: true,
      last_name_fuzzy_alternative: true,
      first_name: true,
      first_name_fuzzy: true,
      first_name_fuzzy_alternative: true,
    }
  end

  subject do
    described_class.new(AamvaFixtures.example_config.to_h)
  end

  let(:verification_response) { AamvaFixtures.verification_response }

  before do
    stub_request(:post, AamvaFixtures.example_config.auth_url).
      to_return(
        { body: AamvaFixtures.security_token_response },
        { body: AamvaFixtures.authentication_token_response },
      )
    stub_request(:post, AamvaFixtures.example_config.verification_url).
      to_return(body: verification_response)
  end

  describe '#proof' do
    context 'when verification is successful' do
      it 'the result is successful' do
        result = subject.proof(state_id_data)

        expect(result.success?).to eq(true)
        # TODO: Find a better way to express this than errors
        expect(result.transaction_id).to eq('1234-abcd-efgh')
        expect(result.errors).to eq({})
        expect(result.vendor_name).to eq('aamva:state_id')
        expect(result.exception).to eq(nil)
        expect(result.timed_out?).to eq(false)

        expect(result.verified_attributes).to eq(
          %i[
            dob
            state_id_number
            state_id_type
            last_name
            first_name
            address
          ].to_set,
        )
      end
    end

    context 'when verification is unsuccessful' do
      let(:verification_response) do
        XmlHelper.modify_xml_at_xpath(
          super(),
          '//PersonBirthDateMatchIndicator',
          'false',
        )
      end

      it 'the result should be failed' do
        result = subject.proof(state_id_data)

        expect(result.success?).to eq(false)
        expect(result.errors).to include(dob: ['UNVERIFIED'])
        expect(result.transaction_id).to eq('1234-abcd-efgh')
        expect(result.vendor_name).to eq('aamva:state_id')
        expect(result.exception).to eq(nil)
        expect(result.timed_out?).to eq(false)

        expect(result.verified_attributes).to eq(
          %i[
            state_id_number
            state_id_type
            last_name
            first_name
            address
          ].to_set,
        )
      end
    end

    context 'when verification attributes are missing' do
      let(:verification_response) do
        XmlHelper.delete_xml_at_xpath(
          super(),
          '//PersonBirthDateMatchIndicator',
        )
      end

      it 'the result should be failed' do
        result = subject.proof(state_id_data)

        expect(result.success?).to eq(false)
        expect(result.errors).to include(dob: ['MISSING'])
        expect(result.transaction_id).to eq('1234-abcd-efgh')
        expect(result.vendor_name).to eq('aamva:state_id')
        expect(result.exception).to eq(nil)
        expect(result.timed_out?).to eq(false)

        expect(result.verified_attributes).to eq(
          %i[
            state_id_number
            state_id_type
            last_name
            first_name
            address
          ].to_set,
        )
      end
    end

    context 'when AAMVA throws an exception' do
      let(:exception) { RuntimeError.new }

      before do
        allow_any_instance_of(::Proofing::Aamva::Request::VerificationRequest).
          to receive(:send).and_raise(exception)
      end

      it 'logs to NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error)

        result = subject.proof(state_id_data)

        expect(result.success?).to eq(false)
        expect(result.exception).to eq(exception)
        expect(result.mva_exception?).to eq(false)
      end

      context 'the exception is a timeout error' do
        let(:exception) { Proofing::TimeoutError.new }

        it 'logs to NewRelic' do
          expect(NewRelic::Agent).to receive(:notice_error)

          result = subject.proof(state_id_data)

          expect(result.success?).to eq(false)
          expect(result.exception).to eq(exception)
          expect(result.mva_unavailable?).to eq(false)
          expect(result.mva_system_error?).to eq(false)
          expect(result.mva_timeout?).to eq(false)
          expect(result.mva_exception?).to eq(false)
        end
      end

      context 'the exception is a verification error due to the MVA being unavailable' do
        let(:exception) do
          Proofing::Aamva::VerificationError.new(
            'DLDV VSS - ExceptionId: 0001, ExceptionText: MVA system is unavailable',
          )
        end

        it 'logs to NewRelic' do
          expect(NewRelic::Agent).to receive(:notice_error)

          result = subject.proof(state_id_data)

          expect(result.success?).to eq(false)
          expect(result.exception).to eq(exception)
          expect(result.mva_unavailable?).to eq(true)
          expect(result.mva_system_error?).to eq(false)
          expect(result.mva_timeout?).to eq(false)
          expect(result.mva_exception?).to eq(true)
        end
      end

      context 'the exception is a verification error due to a MVA system error' do
        let(:exception) do
          Proofing::Aamva::VerificationError.new(
            'DLDV VSS - ExceptionId: 0002, ExceptionText: MVA system error',
          )
        end

        it 'logs to NewRelic' do
          expect(NewRelic::Agent).to receive(:notice_error)

          result = subject.proof(state_id_data)

          expect(result.success?).to eq(false)
          expect(result.exception).to eq(exception)
          expect(result.mva_unavailable?).to eq(false)
          expect(result.mva_system_error?).to eq(true)
          expect(result.mva_timeout?).to eq(false)
          expect(result.mva_exception?).to eq(true)
        end
      end

      context 'the exception is a verification error due to a MVA timeout' do
        let(:exception) do
          Proofing::Aamva::VerificationError.new(
            'DLDV VSS - ExceptionId: 0047, ExceptionText: MVA did not respond in a timely fashion',
          )
        end

        it 'does not log to NewRelic' do
          expect(NewRelic::Agent).not_to receive(:notice_error)

          result = subject.proof(state_id_data)

          expect(result.success?).to eq(false)
          expect(result.exception).to eq(exception)
          expect(result.mva_unavailable?).to eq(false)
          expect(result.mva_system_error?).to eq(false)
          expect(result.mva_timeout?).to eq(true)
          expect(result.mva_exception?).to eq(true)
        end
      end
    end
  end
end
