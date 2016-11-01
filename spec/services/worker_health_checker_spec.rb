require 'rails_helper'

RSpec.describe WorkerHealthChecker do
  before do
    ActiveJob::Base.queue_adapter = :sidekiq
    Sidekiq.redis(&:flushdb)
  end

  after do
    Sidekiq.redis(&:flushdb)
    ActiveJob::Base.queue_adapter = :test
  end

  def create_sidekiq_queues(*queues)
    # TODO: find an API to use rather than manually mess with redis?
    Sidekiq.redis do |redis|
      queues.each do |queue|
        redis.sadd('queues', queue)
      end
    end
  end

  describe '#enqueue_dummy_jobs' do
    let(:queue1) { 'queue1' }
    let(:queue2) { 'queue2' }

    before do
      create_sidekiq_queues(queue1, queue2)
    end

    subject(:enqueue_dummy_jobs) { WorkerHealthChecker.enqueue_dummy_jobs }

    it 'queues a dummy job per queue that update health per job' do
      expect(WorkerHealthChecker.healthy?(queue1)).to eq(false)
      expect(WorkerHealthChecker.healthy?(queue2)).to eq(false)

      enqueue_dummy_jobs

      expect(WorkerHealthChecker.healthy?(queue1)).to eq(true)
      expect(WorkerHealthChecker.healthy?(queue2)).to eq(true)
    end
  end

  describe '#check' do
    let(:queue1) { 'queue1' }
    let(:queue2) { 'queue2' }
    subject(:check) { WorkerHealthChecker.check }

    before do
      create_sidekiq_queues(queue1, queue2)
    end

    context 'successful jobs have run in all queues' do
      before do
        WorkerHealthChecker::DummyJob.set(queue: queue1).perform_later
        WorkerHealthChecker::DummyJob.set(queue: queue2).perform_later
      end

      it 'does not report anything to NewRelic' do
        expect(NewRelic::Agent).to_not receive(:notice_error)
        check
      end
    end

    context 'successful jobs have run in some queues' do
      before do
        WorkerHealthChecker::DummyJob.set(queue: queue1).perform_later
      end

      it 'reports errors to NewRelic for the failing queues' do
        expect(NewRelic::Agent).to receive(:notice_error).
          with(WorkerHealthChecker::QueueHealthError.new('Background queue queue2 is unhealthy'))
        check
      end
    end
  end

  describe '#mark_healthy!' do
    let(:queue) { 'myqueue' }
    let(:now) { Time.zone.now }

    it 'sets a key in redis' do
      expect { WorkerHealthChecker.mark_healthy!(queue, now: now) }.
        to change { WorkerHealthChecker.healthy?(queue, now: now) }.
        from(false).to(true)
    end
  end

  describe '#healthy?' do
    let(:queue) { 'myqueue' }
    let(:now) { Time.zone.now }
    subject(:healthy?) { WorkerHealthChecker.healthy?(queue, now: now) }

    context 'no value in redis' do
      it { is_expected.to be(false) }
    end

    context 'a recent healthy timestamp in redis' do
      before { WorkerHealthChecker.mark_healthy!(queue, now: now) }

      it { is_expected.to be(true) }
    end

    context 'an old healthy timestamp in redis' do
      before { WorkerHealthChecker.mark_healthy!(queue, now: now - 500) }

      it { is_expected.to be(false) }
    end
  end
end
