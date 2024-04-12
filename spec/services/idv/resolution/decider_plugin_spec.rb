require 'rails_helper'

RSpec.describe Idv::Resolution::DeciderPlugin do
  let(:input) { nil }

  let(:threatmetrix_result) { nil }

  let(:instant_verify_result) { nil }

  let(:aamva_result) { nil }

  let(:result) do
    {
      threatmetrix: threatmetrix_result,
      instant_verify: instant_verify_result,
      aamva: aamva_result,
    }.compact
  end

  subject(:failed_checks) do
    to_return = []
    described_class.new.call(
      input:,
      result:,
      next_plugin: ->(decider:, **) {
        to_return = decider[:failed_checks]
      },
    )
    to_return
  end

  it 'fails by default' do
    described_class.new.call(
      input:,
      result:,
      next_plugin: next_plugin_expecting(
        decider: {
          result: :fail,
          failed_checks: %i[
            input_includes_state_id
            input_includes_address_of_residence
            threatmetrix_ran
            threatmetrix_success
            instant_verify_ran
            instant_verify_address_of_residence_success
            instant_verify_state_id_address_success
            aamva_ran
            aamva_state_id_address_success_or_unsupported_jurisdiction
          ],
        },
      ),
    )
  end

  describe 'ThreatMetrix' do
    context 'did not run' do
      it 'fails ThreatMetrix checks' do
        expect(failed_checks).to include(
          :threatmetrix_ran,
          :threatmetrix_success,
        )
      end
    end

    context 'ran successfully' do
      let(:threatmetrix_result) { Proofing::DdpResult.new(success: true) }
      it 'passes ThreatMetrix checks' do
        expect(failed_checks).not_to include(
          :threatmetrix_ran,
          :threatmetrix_success,
        )
      end
    end

    context 'ran unsuccessfully' do
      let(:threatmetrix_result) { Proofing::DdpResult.new(success: false) }
      it 'fails ThreatMetrix checks' do
        expect(failed_checks).not_to include(
          :threatmetrix_ran,
        )
        expect(failed_checks).to include(
          :threatmetrix_success,
        )
      end
    end
  end

  describe 'InstantVerify' do
    context 'did not run' do
      it 'fails InstantVerify checks' do
        expect(failed_checks).to include(
          :instant_verify_ran,
          :instant_verify_address_of_residence_success,
          :instant_verify_state_id_address_success,
        )
      end
    end

    context 'ran only for state_id_address' do
      it 'fails InstantVerify checks'
    end

    context 'ran only for address_of_residence' do
      it 'fails InstantVerify checks'
    end

    context 'ran for state_id_address and address_of_residence' do
      context 'passing both' do
        it 'passes InstantVerify checks'
      end
      context 'failing state_id_address' do
        it 'fails InstantVerify checks'
      end
      context 'failing address_of_residence' do
        it 'fails InstantVerify checks'
      end
    end
  end

  def next_plugin_expecting(*args, **kwargs)
    next_plugin = spy
    expect(next_plugin).to receive(:call).with(*args, **kwargs)
    next_plugin
  end
end
