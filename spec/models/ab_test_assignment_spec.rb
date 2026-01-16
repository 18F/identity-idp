require 'rails_helper'

RSpec.describe AbTestAssignment do
  describe '.bucket' do
    subject(:bucket) { AbTestAssignment.bucket(**args) }
    let(:args) { { experiment: 'experiment', discriminator: 'discriminator' } }
    let!(:ab_test_assignment) do
      create(
        :ab_test_assignment,
        experiment: 'experiment',
        discriminator: 'discriminator',
        bucket: 'bucket',
      )
    end

    it 'returns bucket for the matched record' do
      expect(bucket).to eq(:bucket)
    end

    context 'without a matched record' do
      let!(:ab_test_assignment) { nil }

      it { is_expected.to be_nil }
    end
  end
end
