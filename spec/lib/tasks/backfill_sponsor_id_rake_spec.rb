require 'rails_helper'
require 'rake'

RSpec.describe 'in_person_enrollments:backfill_sponsor_id rake task' do
  let!(:task) do
    Rake.application.rake_require 'tasks/backfill_sponsor_id'
    Rake::Task.define_task(:environment)
    Rake::Task['in_person_enrollments:backfill_sponsor_id']
  end

  subject(:invoke_task) do
    actual_stderr = $stderr
    proxy_stderr = StringIO.new
    begin
      $stderr = proxy_stderr
      task.reenable
      task.invoke
      proxy_stderr.string
    ensure
      $stderr = actual_stderr
    end
  end

  let(:pending_enrollment) { create(:in_person_enrollment, :pending) }
  let(:expired_enrollment) { create(:in_person_enrollment, :expired) }
  let(:failed_enrollment) { create(:in_person_enrollment, :failed) }
  let(:enrollment_with_service_provider) do
    create(:in_person_enrollment, :with_service_provider)
  end
  let(:enrollment_with_sponsor_id) { create(:in_person_enrollment) }

  before do
    allow(IdentityConfig.store).to receive(:usps_ipp_sponsor_id).and_return('31459')
  end

  it 'does not change the value of an existing sponsor id' do
    original_sponsor_id = enrollment_with_sponsor_id.sponsor_id
    subject
    expect(enrollment_with_sponsor_id.sponsor_id).to eq(original_sponsor_id)
  end

  it 'sets a sponsor id that is a string' do
    subject
    enrollments = InPersonEnrollment.all
    enrollments.each do |enrollment|
      expect(enrollment.sponsor_id).to be_a String
    end
  end
end
