require 'rails_helper'
require 'rake'

describe 'review_profile' do
  before do
    Rake.application.rake_require('lib/tasks/review_profile', [Rails.root.to_s])
    Rake::Task.define_task(:environment)
  end

  describe 'users:review:pass' do
    it 'sets threatmetrix_review_status to pass' do
      user = create(:user, :deactivated_threatmetrix_profile)

      allow(STDIN).to receive(:getpass) { user.uuid }

      Rake::Task['users:review:pass'].invoke
      expect(user.reload.proofing_component.threatmetrix_review_status).to eq('pass')
      expect(user.reload.profiles.first.active).to eq(true)
    end
  end

  describe 'users:review:reject' do
    it 'sets threatmetrix_review_status to reject' do
      user = create(:user, :deactivated_threatmetrix_profile)

      allow(STDIN).to receive(:getpass) { user.uuid }

      Rake::Task['users:review:reject'].invoke
      expect(user.reload.proofing_component.threatmetrix_review_status).to eq('reject')
      expect(user.reload.profiles.first.deactivation_reason).to eq('threatmetrix_review_rejected')
    end
  end
end
