require 'rails_helper'
require 'ostruct'

RSpec.describe Proofing::Aamva::Proofer do
  let(:aamva_applicant) do
    Aamva::Applicant.from_proofer_applicant(state_id_data)
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

      def self.when_missing(&block)
        context 'when missing' do
          let(:verification_response) do
            XmlHelper.delete_xml_at_xpath(
              AamvaFixtures.verification_response,
              "//#{match_indicator_name}",
            )
          end

          instance_eval(&block)
        end
      end

      def self.when_unverified(&block)
        context 'when unverified' do
          let(:verification_response) do
            XmlHelper.modify_xml_at_xpath(
              AamvaFixtures.verification_response,
              "//#{match_indicator_name}",
              'false',
            )
          end

          instance_eval(&block)
        end
      end

      def self.test_in_requested_attributes(logged_attribute = nil)
        if logged_attribute
          it "does not stop #{logged_attribute} from appearing in requested_attributes" do
            expect(result.requested_attributes).to include(logged_attribute => 1)
          end
          it 'does not itself appear in requested_attributes' do
            expect(result.requested_attributes).not_to include(attribute => 1)
          end
        else
          it 'appears in requested_attributes' do
            expect(result.requested_attributes).to include(attribute => 1)
          end
        end
      end

      def self.test_not_in_requested_attributes(logged_attribute = nil)
        if logged_attribute
          it "stops #{logged_attribute} from appearing in requested_attributes" do
            expect(result.requested_attributes).not_to include(logged_attribute => 1)
          end
        end
        it 'does not appear in requested_attributes' do
          expect(result.requested_attributes).not_to include(attribute => 1)
        end
      end

      def self.test_in_verified_attributes(logged_attribute)
        it "does not stop #{logged_attribute} from appearing in verified_attributes" do
          expect(result.verified_attributes).to include(logged_attribute)
        end

        it 'does not itself appear in verified_attributes' do
          expect(result.verified_attributes).not_to include(attribute)
        end
      end

      def self.test_not_in_verified_attributes(logged_attribute = nil)
        if logged_attribute
          it "stops #{logged_attribute} from appearing in verified_attributes" do
            expect(result.verified_attributes).not_to include(logged_attribute)
          end
        end
        it 'does not appear in verified_attributes' do
          expect(result.verified_attributes).not_to include(attribute)
        end
      end

      def self.test_still_successful
        it 'the result is still successful' do
          expect(result.success?).to be true
        end
      end

      def self.test_not_successful
        it 'the result is not successful' do
          expect(result.success?).to be false
        end
      end

      describe '#address1' do
        let(:attribute) { :address1 }
        let(:match_indicator_name) { 'AddressLine1MatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes(:address)
          test_not_in_verified_attributes(:address)
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes(:address)
          test_not_in_verified_attributes(:address)
        end
      end

      describe '#address2' do
        let(:attribute) { :address2 }
        let(:match_indicator_name) { 'AddressLine2MatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes(:address)
          test_in_verified_attributes(:address)
        end

        when_missing do
          test_still_successful
          test_in_requested_attributes(:address)
          test_in_verified_attributes(:address)
        end
      end

      describe '#city' do
        let(:attribute) { :city }
        let(:match_indicator_name) { 'AddressCityMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes(:address)
          test_not_in_verified_attributes(:address)
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes(:address)
          test_not_in_verified_attributes(:address)
        end
      end

      describe '#state' do
        let(:attribute) { :city }
        let(:match_indicator_name) { 'AddressStateCodeMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes(:address)
          test_not_in_verified_attributes(:address)
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes(:address)
          test_not_in_verified_attributes(:address)
        end
      end

      describe '#zipcode' do
        let(:attribute) { :zipcode }
        let(:match_indicator_name) { 'AddressZIP5MatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes(:address)
          test_not_in_verified_attributes(:address)
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes(:address)
          test_not_in_verified_attributes(:address)
        end
      end

      describe '#dob' do
        let(:attribute) { :dob }
        let(:match_indicator_name) { 'PersonBirthDateMatchIndicator' }

        when_unverified do
          test_not_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_not_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#state_id_issued' do
        let(:attribute) { :state_id_issued }
        let(:match_indicator_name) { 'DriverLicenseIssueDateMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#state_id_number' do
        let(:attribute) { :state_id_number }
        let(:match_indicator_name) { 'DriverLicenseNumberMatchIndicator' }

        when_unverified do
          test_not_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_not_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#state_id_expiration' do
        let(:attribute) { :state_id_expiration }
        let(:match_indicator_name) { 'DriverLicenseExpirationDateMatchIndicator' }

        when_unverified do
          test_not_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#state_id_type' do
        let(:attribute) { :state_id_type }
        let(:match_indicator_name) { 'DocumentCategoryMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#first_name' do
        let(:attribute) { :first_name }
        let(:match_indicator_name) { 'PersonFirstNameExactMatchIndicator' }

        when_unverified do
          test_not_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_not_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#last_name' do
        let(:attribute) { :last_name }
        let(:match_indicator_name) { 'PersonLastNameExactMatchIndicator' }

        when_unverified do
          test_not_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_not_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#middle_name' do
        let(:attribute) { :middle_name }
        let(:match_indicator_name) { 'PersonMiddleNameExactMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#name_suffix' do
        let(:attribute) { :name_suffix }
        let(:match_indicator_name) { 'PersonNameSuffixMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#height' do
        let(:attribute) { :height }
        let(:match_indicator_name) { 'PersonHeightMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#sex' do
        let(:attribute) { :sex }
        let(:match_indicator_name) { 'PersonSexCodeMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#weight' do
        let(:attribute) { :weight }
        let(:match_indicator_name) { 'PersonWeightMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
      end

      describe '#eye_color' do
        let(:attribute) { :eye_color }
        let(:match_indicator_name) { 'PersonEyeColorMatchIndicator' }

        when_unverified do
          test_still_successful
          test_in_requested_attributes
          test_not_in_verified_attributes
        end

        when_missing do
          test_still_successful
          test_not_in_requested_attributes
          test_not_in_verified_attributes
        end
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
            middle_name
            name_suffix
            address
            height
            sex
            weight
            eye_color
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
            middle_name: 1,
            name_suffix: 1,
            address: 1,
            height: 1,
            sex: 1,
            weight: 1,
            eye_color: 1,
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
            middle_name
            name_suffix
            address
            height
            sex
            weight
            eye_color
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
            middle_name: 1,
            name_suffix: 1,
            address: 1,
            height: 1,
            sex: 1,
            weight: 1,
            eye_color: 1,
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
            middle_name
            name_suffix
            address
            height
            sex
            weight
            eye_color
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
            middle_name: 1,
            name_suffix: 1,
            address: 1,
            height: 1,
            sex: 1,
            weight: 1,
            eye_color: 1,
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
