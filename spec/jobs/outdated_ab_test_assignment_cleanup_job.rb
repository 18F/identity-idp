require 'rails_helper'

RSpec.describe OutdatedAbTestAssignmentCleanupJob, type: :job do
  subject(:job) { described_class.new }

  describe '#perform' do
    subject(:result) { job.perform }

    it 'deletes ab test assignments for experiments no longer configured' do
      configured_experiment = AbTests.all.values.sample.experiment

      create(:ab_test_assignment, experiment: configured_experiment)
      create(:ab_test_assignment, experiment: 'outdated')

      expect { result }.to change { AbTestAssignment.all.map(&:experiment) }
        .from([configured_experiment, 'outdated'])
        .to([configured_experiment])
    end
  end
end
