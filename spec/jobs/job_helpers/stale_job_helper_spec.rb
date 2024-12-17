require 'rails_helper'

RSpec.describe JobHelpers::StaleJobHelper do
  let(:klass) do
    Class.new do
      include JobHelpers::StaleJobHelper
    end
  end

  let(:instance) { klass.new }
  let(:async_stale_job_timeout_seconds) { 300 }

  before do
    allow(IdentityConfig.store).to receive(:async_stale_job_timeout_seconds)
      .and_return(async_stale_job_timeout_seconds)
  end

  describe '#stale_job?' do
    subject(:stale_job?) { instance.stale_job?(enqueued_at) }

    context 'with a nil enqueued_at' do
      let(:enqueued_at) { nil }

      it { is_expected.to be_falsey }
    end

    context 'with a recent enqueued_at' do
      let(:enqueued_at) { 10.seconds.ago }

      it { is_expected.to be_falsey }
    end

    context 'with a stale enqueued_at' do
      let(:enqueued_at) { 500.seconds.ago }

      it { is_expected.to be_truthy }
    end
  end

  describe '#raise_stale_job!' do
    it 'raises' do
      expect { instance.raise_stale_job! }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
    end
  end
end
