require 'rails_helper'

RSpec.describe AbTestAssignment do
  it 'has created_at and updated_at timestamps' do
    assignment = AbTestAssignment.create!(
      experiment: 'test_exp',
      discriminator: 'test_disc',
      bucket: 'test_bucket',
    )

    expect(assignment.created_at).to be_present
    expect(assignment.updated_at).to be_present
  end

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
