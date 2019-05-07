require 'rails_helper'

describe JobRun do
  it 'recent errors' do
    since = Time.zone.now

    job_run = JobRun.new
    job_run.job_name = 'Test job'
    job_run.error = 'This is recent'
    job_run.save!
    jr = JobRun.find_recent_errors(since)
    expect(jr).to_not be_nil
  end

  it 'no recent errors' do
    since = Time.zone.now

    job_run = JobRun.new
    job_run.job_name = 'Test job'
    job_run.save!
    jr = JobRun.find_recent_errors(since)

    expect(jr).to_not exist
  end

  it 'mark as timed out with bad argument' do
    job_run = JobRun.new
    job_run.job_name = 'Test job timing out'
    job_run.result = 'fake result'
    job_run.save!

    expect { job_run.mark_as_timed_out }.to raise_error(ArgumentError)
  end

  it 'mark as timed out with good argument' do
    job_run = JobRun.new
    job_run.job_name = 'Test job timing out'
    job_run.save!
    job_run.mark_as_timed_out

    expect(job_run.error).to have_attributes(upcase: 'TIMEOUT')
  end
end
