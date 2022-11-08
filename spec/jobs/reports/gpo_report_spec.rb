require 'rails_helper'

describe Reports::GpoReport do
  subject { described_class.new }
  let(:empty_report) do
    {
      'letters_sent_and_validated_since_days' => {
        '10000' => 0, '14' => 0, '30' => 0, '60' => 0, '7' => 0, '90' => 0
      },
      'letters_sent_since_days' => {
        '10000' => 0, '14' => 0, '30' => 0, '60' => 0, '7' => 0, '90' => 0
      },
      'percent_sent_and_validated_since_days' => {
        '10000' => 0, '14' => 0, '30' => 0, '60' => 0, '7' => 0, '90' => 0
      },
      'today' => Time.zone.today.to_s,
    }
  end
  let(:one_letter_sent_and_verified_report) do
    {
      'letters_sent_and_validated_since_days' => {
        '10000' => 1, '14' => 1, '30' => 1, '60' => 1, '7' => 1, '90' => 1
      },
      'letters_sent_since_days' => {
        '10000' => 1, '14' => 1, '30' => 1, '60' => 1, '7' => 1, '90' => 1
      },
      'percent_sent_and_validated_since_days' => {
        '10000' => 100.0, '14' => 100.0, '30' => 100.0, '60' => 100.0, '7' => 100.0, '90' => 100.0
      },
      'today' => Time.zone.today.to_s,
    }
  end
  let(:user) { create(:user) }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }

  it 'correctly reports zero letters sent' do
    expect(JSON.parse(subject.perform(Time.zone.today))).to eq(empty_report)
  end

  it 'correctly reports one letter sent that was verified' do
    create_ucc_for(profile)
    expect(JSON.parse(subject.perform(Time.zone.today))).to eq(one_letter_sent_and_verified_report)
  end

  describe '#good_job_concurrency_key' do
    let(:date) { Time.zone.today }

    it 'is the job name and the date' do
      job = described_class.new(date)
      expect(job.good_job_concurrency_key).
        to eq("#{described_class::REPORT_NAME}-#{date}")
    end
  end

  def create_ucc_for(profile)
    GpoConfirmationCode.create(
      profile: profile,
      otp_fingerprint: 'foo',
    )
  end
end
