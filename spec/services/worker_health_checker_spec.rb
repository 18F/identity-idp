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
      expect(WorkerHealthChecker.status(queue1).healthy?).to eq(false)
      expect(WorkerHealthChecker.status(queue2).healthy?).to eq(false)

      enqueue_dummy_jobs

      expect(WorkerHealthChecker.status(queue1).healthy?).to eq(true)
      expect(WorkerHealthChecker.status(queue2).healthy?).to eq(true)
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

      it 'logs a message so we can audit that the job is running in our logs' do
        expect(Rails.logger).to receive(:info).
          with(hash_including(event: 'checking background queues'))

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
        to change { WorkerHealthChecker.status(queue, now: now).healthy? }.
        from(false).to(true)
    end
  end

  describe '#summary' do
    let(:now) { Time.zone.now }
    subject(:summary) { WorkerHealthChecker.summary(now: now) }

    let(:queue1) { 'queue1' }
    let(:queue2) { 'queue2' }

    before do
      create_sidekiq_queues(queue1, queue2)
      WorkerHealthChecker.mark_healthy!(queue1, now: now)
    end

    it 'creates a snapshot summary of the queues' do
      expect(summary.statuses.length).to eq(2)

      queue1_status, queue2_status = summary.statuses.sort_by(&:queue)

      expect(queue1_status.queue).to eq('queue1')
      expect(queue1_status.last_run_at.to_i).to eq(now.to_i)
      expect(queue1_status.healthy).to eq(true)

      expect(queue2_status.queue).to eq('queue2')
      expect(queue2_status.last_run_at).to be_nil
      expect(queue2_status.healthy).to eq(false)
    end

    it 'is unhealthy when not all queues are healthy' do
      expect(summary.all_healthy?).to eq(false)
    end

    context 'when all queues are healthy' do
      before { WorkerHealthChecker.mark_healthy!(queue2, now: now) }

      it 'is all healthy' do
        expect(summary.all_healthy?).to eq(true)
      end
    end
  end
end
