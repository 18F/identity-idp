require 'rails_helper'
require 'ostruct'

# This helper method generates a set of tests for a specific attribute.
# They assume that `verification_response` contains a DLDV XML response
# where all attributes are present and valid, and `result` contains
# the result from the proofer.
# @param [Symbol] attribute_name
# @param [String] match_indicator_name Tag name for the match indicator in the DLDV XML response
# @param [Boolean] required Whether this attribute must verfy for overall success
# @param [nil,Symbol] required_part_of The meta-attribute this attribute is required for
#                                      (e.g. :address for :city)
# @param [nil,Symbol] optional_part_of The meta-attribute this attribute is an optional part of
#                                      (e.g. :address for :address2)
def test_aamva_attribute(
  attribute_name,
  match_indicator_name:,
  required: false,
  required_part_of: nil,
  optional_part_of: nil
)
  context 'when unverified' do
    let(:verification_response) do
      XmlHelper.modify_xml_at_xpath(
        super(),
        "//#{match_indicator_name}",
        'false',
      )
    end

    if required
      it('makes the result not succeed') do
        expect(result.success?).to be false
      end
    else
      it 'does not stop result from succeeding' do
        expect(result.success?).to be true
      end
    end

    if required_part_of
      it "does not stop #{required_part_of} appearing in requested_attributes" do
        expect(result.requested_attributes).to include(required_part_of => 1)
      end
      it "makes #{required_part_of} not appear in verfied_attributes" do
        expect(result.verified_attributes).not_to include(required_part_of)
      end
      it 'does not appear in requested_attributes' do
        expect(result.requested_attributes).not_to include(attribute_name => 1)
      end
    elsif optional_part_of
      it "does not stop #{optional_part_of} appearing in requested_attributes" do
        expect(result.requested_attributes).to include(optional_part_of => 1)
      end
      it "does not stop #{optional_part_of} appearing in verfied_attributes" do
        expect(result.requested_attributes).to include(optional_part_of)
      end
      it 'does not appear in requested_attributes' do
        expect(result.requested_attributes).not_to include(attribute_name => 1)
      end
    else
      it 'still appears in requested_attributes' do
        expect(result.requested_attributes).to include(attribute_name => 1)
      end
    end
    it 'does not appear in verified_attributes' do
      expect(result.verified_attributes).not_to include(attribute_name)
    end
  end

  context 'when missing' do
    let(:verification_response) do
      XmlHelper.delete_xml_at_xpath(
        super(),
        "//#{match_indicator_name}",
      )
    end

    if required
      it('makes the result not succeed') do
        expect(result.success?).to be false
      end
    else
      it 'makes the result still succeed' do
        expect(result.success?).to be true
      end
    end

    if required_part_of
      it "makes #{required_part_of} not appear in requested_attributes" do
        expect(result.requested_attributes).not_to include(required_part_of => 1)
      end
      it "makes #{required_part_of} not appear in verfied_attributes" do
        expect(result.verified_attributes).not_to include(required_part_of)
      end
    elsif optional_part_of
      it "does not stop #{optional_part_of} appearing in requested_attributes" do
        expect(result.requested_attributes).to include(optional_part_of => 1)
      end
      it "does not stop #{optional_part_of} appearing in verfied_attributes" do
        expect(result.requested_attributes).to include(optional_part_of)
      end
    end

    it 'does not appear in requested_attributes' do
      expect(result.requested_attributes).not_to include(attribute_name => 1)
    end

    it 'does not appear in verified_attributes' do
      expect(result.verified_attributes).not_to include(attribute_name)
    end
  end
end

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

  let(:verification_result) do
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
    describe 'individual attributes' do
      subject(:result) do
        described_class.new(AamvaFixtures.example_config.to_h).proof(state_id_data)
      end

      describe '#address1' do
        test_aamva_attribute(
          :address1,
          match_indicator_name: 'AddressLine1MatchIndicator',
          required_part_of: :address,
        )
      end

      describe '#address2' do
        test_aamva_attribute(
          :address2,
          match_indicator_name: 'AddressLine2MatchIndicator',
          optional_part_of: :address,
        )
      end

      describe '#city' do
        test_aamva_attribute(
          :city,
          match_indicator_name: 'AddressCityMatchIndicator',
          required_part_of: :address,
        )
      end

      describe '#state' do
        test_aamva_attribute(
          :state,
          match_indicator_name: 'AddressStateCodeMatchIndicator',
          required_part_of: :address,
        )
      end
      describe '#zipcode' do
        test_aamva_attribute(
          :zipcode,
          match_indicator_name: 'AddressZIP5MatchIndicator',
          required_part_of: :address,
        )
      end
      describe '#dob' do
        test_aamva_attribute(
          :dob,
          match_indicator_name: 'PersonBirthDateMatchIndicator',
          required: true,
        )
      end
      describe '#state_id_issued' do
        test_aamva_attribute(
          :state_id_issued,
          match_indicator_name: 'DriverLicenseIssueDateMatchIndicator',
          required: false,
        )
      end
      describe '#state_id_number' do
        test_aamva_attribute(
          :state_id_number,
          match_indicator_name: 'DriverLicenseNumberMatchIndicator',
          required: true,
        )
      end
      describe '#state_id_expiration' do
        test_aamva_attribute(
          :state_id_expiration,
          match_indicator_name: 'DriverLicenseExpirationDateMatchIndicator',
          required: false,
        )
      end
      describe '#state_id_type' do
        test_aamva_attribute(
          :state_id_type,
          match_indicator_name: 'DocumentCategoryMatchIndicator',
          required: false,
        )
      end
      describe '#first_name' do
        test_aamva_attribute(
          :first_name,
          match_indicator_name: 'PersonFirstNameExactMatchIndicator',
          required: true,
        )
      end
      describe '#last_name' do
        test_aamva_attribute(
          :last_name,
          match_indicator_name: 'PersonLastNameExactMatchIndicator',
          required: true,
        )
      end
    end

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
            state_id_issued
            state_id_expiration
            state_id_number
            state_id_type
            last_name
            first_name
            address
          ].to_set,
        )
      end

      it 'includes requested_attributes' do
        result = subject.proof(state_id_data)
        expect(result.requested_attributes).to eq(
          {
            dob: 1,
            state_id_issued: 1,
            state_id_expiration: 1,
            state_id_number: 1,
            state_id_type: 1,
            last_name: 1,
            first_name: 1,
            address: 1,
          },
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
            state_id_expiration
            state_id_issued
            state_id_number
            state_id_type
            last_name
            first_name
            address
          ].to_set,
        )
      end

      it 'includes requested_attributes' do
        result = subject.proof(state_id_data)
        expect(result.requested_attributes).to eq(
          {
            dob: 1,
            state_id_expiration: 1,
            state_id_issued: 1,
            state_id_number: 1,
            state_id_type: 1,
            last_name: 1,
            first_name: 1,
            address: 1,
          },
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
            state_id_expiration
            state_id_issued
            state_id_number
            state_id_type
            last_name
            first_name
            address
          ].to_set,
        )
      end

      it 'includes requested_attributes' do
        result = subject.proof(state_id_data)
        expect(result.requested_attributes).to eq(
          {
            state_id_expiration: 1,
            state_id_issued: 1,
            state_id_number: 1,
            state_id_type: 1,
            last_name: 1,
            first_name: 1,
            address: 1,
          },
        )
      end
    end

    context 'when issue / expiration present' do
      let(:state_id_data) do
        {
          state_id_number: '1234567890',
          state_id_jurisdiction: 'VA',
          state_id_type: 'drivers_license',
          state_id_issued: '2023-04-05',
          state_id_expiration: '2030-01-02',
        }
      end

      it 'includes them' do
        expect(Proofing::Aamva::Request::VerificationRequest).to receive(:new).with(
          hash_including(
            applicant: satisfy do |a|
              expect(a.state_id_data.state_id_issued).to eql('2023-04-05')
              expect(a.state_id_data.state_id_expiration).to eql('2030-01-02')
            end,
          ),
        )
        subject.proof(state_id_data)
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

    context 'when the DMV is in a defined maintenance window' do
      before do
        expect(Idv::AamvaStateMaintenanceWindow).to receive(:in_maintenance_window?).
          and_return(true)
      end

      it 'sets jurisdiction_in_maintenance_window to true' do
        result = subject.proof(state_id_data)
        expect(result.jurisdiction_in_maintenance_window?).to eq(true)
      end
    end

    context 'when the DMV is not in a defined maintenance window' do
      before do
        expect(Idv::AamvaStateMaintenanceWindow).to receive(:in_maintenance_window?).
          and_return(false)
      end

      it 'sets jurisdiction_in_maintenance_window to false' do
        result = subject.proof(state_id_data)
        expect(result.jurisdiction_in_maintenance_window?).to eq(false)
      end
    end
  end
end
