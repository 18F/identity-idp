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
    let(:queues) { YAML.load_file(Rails.root.join('config', 'sidekiq.yml'))[:queues] }

    subject(:enqueue_dummy_jobs) { WorkerHealthChecker.enqueue_dummy_jobs }

    it 'queues a dummy job per queue that updates health per job' do
      queues.each do |queue|
        expect(WorkerHealthChecker.status(queue).healthy?).to eq(false)
      end

      enqueue_dummy_jobs

      queues.each do |queue|
        expect(WorkerHealthChecker.status(queue).healthy?).to eq(true)
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

  describe '.check' do
    let(:now) { Time.zone.now }
    subject(:check) { WorkerHealthChecker.check(now: now) }

    let(:queue1) { 'queue1' }
    let(:queue2) { 'queue2' }

    before do
      create_sidekiq_queues(queue1, queue2)
      WorkerHealthChecker.mark_healthy!(queue1, now: now)
    end

    it 'creates a snapshot check of the queues' do
      expect(check.statuses.length).to eq(2)

      queue1_status, queue2_status = check.statuses.sort_by(&:queue)

      expect(queue1_status.queue).to eq('queue1')
      expect(queue1_status.last_run_at.to_i).to eq(now.to_i)
      expect(queue1_status.healthy).to eq(true)

      expect(queue2_status.queue).to eq('queue2')
      expect(queue2_status.last_run_at).to be_nil
      expect(queue2_status.healthy).to eq(false)
    end

    it 'is unhealthy when not all queues are healthy' do
      expect(check.healthy?).to eq(false)
    end

    context 'when all queues are healthy' do
      before { WorkerHealthChecker.mark_healthy!(queue2, now: now) }

      it 'is all healthy' do
        expect(check.healthy?).to eq(true)
      end
    end
  end
end
