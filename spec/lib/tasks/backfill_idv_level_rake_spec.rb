require 'rails_helper'
require 'rake'

RSpec.describe 'profiles:backfill_idv_level rake task' do
  let(:task) do
    Rake.application.rake_require 'tasks/backfill_idv_level'
    Rake::Task.define_task(:environment)
    Rake::Task['profiles:backfill_idv_level']
  end

  subject(:invoke_task) do
    og_stderr = $stderr
    fake_stderr = StringIO.new
    begin
      $stderr = fake_stderr
      task.reenable
      task.invoke
      fake_stderr.string
    ensure
      $stderr = og_stderr
    end
  end

  let(:profiles) do
    {
      unsupervised: create(:user, :proofed).active_profile,
      unsupervised_no_level: create(:user, :proofed).active_profile.tap do |profile|
                               profile.update!(idv_level: nil)
                             end,
      in_person: create(
        :user,
        :with_pending_in_person_enrollment,
      ).pending_profile,
      in_person_no_level: create(
        :user,
        :with_pending_in_person_enrollment,
      ).pending_profile.tap { |profile| profile.update!(idv_level: nil) },
    }
  end

  before do
    expect(profiles[:unsupervised].idv_level).not_to be_nil
    expect(profiles[:unsupervised_no_level].idv_level).to be_nil
    expect(profiles[:in_person].idv_level).not_to be_nil
    expect(profiles[:in_person_no_level].idv_level).to be_nil
    invoke_task
  end

  it 'outputs what it did' do
    expect(invoke_task.to_s).to eql(
      <<~END,
        set idv_level for 1 legacy_in_person profile(s)
        set idv_level for 1 legacy_unsupervised profile(s)
        Profile counts by idv_level after update:
        :legacy_in_person: 2
        :legacy_unsupervised: 2
        nil: 0
      END
    )
  end

  it 'updates legacy unsupervised user that was missing value' do
    expect(profiles[:unsupervised_no_level].reload.idv_level).to eql('legacy_unsupervised')
  end

  it 'does not mess up unsupervised user with value' do
    expect(profiles[:unsupervised].reload.idv_level).to eql('legacy_unsupervised')
  end

  it 'updates legacy in person user that was missing value' do
    expect(profiles[:in_person_no_level].reload.idv_level).to eql('legacy_in_person')
  end

  it 'does not mess up in person user with value' do
    expect(profiles[:in_person].reload.idv_level).to eql('legacy_in_person')
  end
end
