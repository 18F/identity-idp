require 'rails_helper'

RSpec.describe Idv::Resolution::ThreatmetrixPlugin do
  let(:proofing_device_profiling) { :enabled }
  let(:input) { nil }

  before do
    allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      and_return(proofing_device_profiling)
  end

  context 'ThreatMetrix collecting disabled' do
    let(:proofing_device_profiling) { :disabled }

    it 'augments result appropriately' do
      next_plugin = spy
      expect(next_plugin).to receive(:call).with(
        threatmetrix: {
          success: false,
          reason: :collecting_disabled,
        },
      )
      subject.call(
        input:,
        result: {},
        next_plugin:,
      )
    end
  end

  context 'ThreatMetrix collecting enabled' do
    context 'No session id present in input' do
      let(:input) do
        Idv::Resolution::Input.new(
          other: {
            threatmetrix_session_id: '',
          },
        )
      end

      it 'Marks with rejected result and calls the next plugin' do
        next_plugin = spy
        expect(next_plugin).to receive(:call).with(
          threatmetrix: {
            success: false,
            reason: :missing_session_id,
            threatmetrix_result: 'reject',
          },
        )

        subject.call(input:, result: {}, next_plugin:)
      end
    end

    let(:email) { 'test@example.org' }
    let(:threatmetrix_session_id) { 'ABCD-1234' }
    let(:ip_address) { '10.10.10.10' }
    let(:sp_app_id) { '1234' }
    let(:ssn) { '999-88-7777' }

    let(:input) do
      Idv::Resolution::Input.from_pii(
        Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN,
      ).with(other: {
        email:,
        ip: ip_address,
        sp_app_id:,
        threatmetrix_session_id:,
        ssn:,
      })
    end

    it 'calls the ThreatMetrix proofer' do
      next_plugin = spy
      expect(next_plugin).to receive(:call).with(
        threatmetrix: instance_of(Proofing::DdpResult),
      )

      expect_any_instance_of(Proofing::Mock::DdpMockClient).to receive(:proof).
        with(
          { address1: '1 FAKE RD',
            address2: nil,
            city: 'GREAT FALLS',
            dob: '1938-10-06',
            email: 'test@example.org',
            first_name: 'FAKEY',
            last_name: 'MCFAKERSON',
            ssn: '999-88-7777',
            request_ip: '10.10.10.10',
            state: 'MT',
            state_id_jurisdiction: 'ND',
            state_id_number: '1111111111111',
            threatmetrix_session_id: 'ABCD-1234',
            uuid_prefix: '1234',
            zipcode: '59010' },
        ).and_call_original

      subject.call(
        input:,
        result: {},
        next_plugin:,
      )
    end
  end
end
