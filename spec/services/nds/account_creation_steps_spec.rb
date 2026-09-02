require 'rails_helper'

RSpec.describe NDS::AccountCreationSteps do
  describe '.steps' do
    it 'is the ordered account/security/verification list' do
      expect(described_class.steps.map { |s| s[:name] }).to eq(%i[account security verification])
    end
  end

  describe '.labels' do
    it 'returns the localized pill labels in order' do
      expect(described_class.labels).to eq(
        [
          I18n.t('step_indicator.flows.account_creation.account'),
          I18n.t('step_indicator.flows.account_creation.security'),
          I18n.t('step_indicator.flows.account_creation.verification'),
        ],
      )
    end
  end

  describe '.index_for' do
    it 'maps step names to their 0-based index' do
      expect(described_class.index_for(:account)).to eq(0)
      expect(described_class.index_for(:security)).to eq(1)
      expect(described_class.index_for(:verification)).to eq(2)
    end

    it 'raises for an unknown step' do
      expect { described_class.index_for(:bogus) }.to raise_error(ArgumentError)
    end
  end

  describe '.progress_args' do
    it 'builds account substep 1/2' do
      expect(described_class.progress_args(step: :account, substep: 1)).to eq(
        steps: described_class.labels,
        current_step: 0,
        current_substep: 1,
        substep_count: 2,
      )
    end

    it 'builds account substep 2/2' do
      expect(described_class.progress_args(step: :account, substep: 2)).to eq(
        steps: described_class.labels,
        current_step: 0,
        current_substep: 2,
        substep_count: 2,
      )
    end

    it 'builds security substep 1/2' do
      expect(described_class.progress_args(step: :security, substep: 1)).to eq(
        steps: described_class.labels,
        current_step: 1,
        current_substep: 1,
        substep_count: 2,
      )
    end

    it 'builds security substep 2/2' do
      expect(described_class.progress_args(step: :security, substep: 2)).to eq(
        steps: described_class.labels,
        current_step: 1,
        current_substep: 2,
        substep_count: 2,
      )
    end

    it 'builds security with no substep counter when substep omitted' do
      expect(described_class.progress_args(step: :security)).to eq(
        steps: described_class.labels,
        current_step: 1,
      )
    end

    it 'builds verification with no substep counter' do
      expect(described_class.progress_args(step: :verification)).to eq(
        steps: described_class.labels,
        current_step: 2,
      )
    end

    it 'omits substep args for steps without a substep count' do
      expect(described_class.progress_args(step: :verification, substep: 1)).to eq(
        steps: described_class.labels,
        current_step: 2,
      )
    end

    it 'produces args that render a valid ProgressComponent' do
      NDS::AccountCreationSteps.steps.each_with_index do |step, index|
        args = described_class.progress_args(step: step[:name], substep: 1)
        component = NDS::ProgressComponent.new(**args)
        expect(component.current_step).to eq(index)
      end
    end
  end
end
