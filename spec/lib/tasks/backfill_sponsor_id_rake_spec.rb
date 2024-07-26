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

  let(:pending_enrollment) { create(:in_person_enrollment, :pending, :with_nil_sponsor_id) }
  let(:expired_enrollment) { create(:in_person_enrollment, :expired, :with_nil_sponsor_id) }
  let(:failed_enrollment) { create(:in_person_enrollment, :failed, :with_nil_sponsor_id) }
  let(:enrollment_with_service_provider) do
    create(:in_person_enrollment, :with_service_provider, :with_nil_sponsor_id)
  end
  let(:enrollment_with_sponsor_id) { create(:in_person_enrollment) }

  before do
    allow(IdentityConfig.store).to receive(:usps_ipp_sponsor_id).and_return('31459')
    # binding.pry
    expect(pending_enrollment.sponsor_id).to be_nil
    expect(expired_enrollment.sponsor_id).to be_nil
    expect(failed_enrollment.sponsor_id).to be_nil
    expect(enrollment_with_service_provider.sponsor_id).to be_nil
    expect(enrollment_with_sponsor_id.sponsor_id).not_to be_nil
  end

  it 'does not change the value of an existing sponsor id' do
    original_sponsor_id = enrollment_with_sponsor_id.sponsor_id
    subject
    expect(enrollment_with_sponsor_id.sponsor_id).to eq(original_sponsor_id)
  end

  it 'sets a sponsor id for every enrollment with a nil sponsor id' do
    enrollments_with_nil_sponsor_id_count = InPersonEnrollment.where(sponsor_id: nil).count
    expect(enrollments_with_nil_sponsor_id_count).to eq(4)
    subject
    enrollments_with_nil_sponsor_id_count = InPersonEnrollment.where(sponsor_id: nil).count
    expect(enrollments_with_nil_sponsor_id_count).to eq(0)
  end

  it 'sets a sponsor id that is a string' do
    subject
    enrollments = InPersonEnrollment.all
    enrollments.each do |enrollment|
      expect(enrollment.sponsor_id).to be_a String
    end
  end

  it 'outputs what it did' do
    expect(invoke_task.to_s).to eql(
      <<~END,
        Found 4 in_person_enrollments needing backfill
        set sponsor_id for 4 in_person_enrollments
        COMPLETE: Updated 4 in_person_enrollments
        0 enrollments without a sponsor id
      END
    )
  end
end
