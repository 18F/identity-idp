require 'rails_helper'

RSpec.describe GoodJobConnectionPoolSize do
  describe '.calculate_worker_pool_size' do
    it 'calculates pool size based and returns an integer' do
      connections = GoodJobConnectionPoolSize.calculate_worker_pool_size(
        queues: IdentityConfig.store.good_job_queues,
        cron_enabled: true,
        max_threads: IdentityConfig.store.good_job_max_threads,
      )
      expect(connections).to be_a(Integer)
    end
  end

  describe '.calculate_primary_pool_size' do
    it 'calculates pool size based and returns an integer' do
      connections = GoodJobConnectionPoolSize.calculate_primary_pool_size(
        queues: IdentityConfig.store.good_job_queues,
        max_threads: IdentityConfig.store.good_job_max_threads,
      )
      expect(connections).to be_a(Integer)
    end
  end

  describe '.num_explicit_threads_from_queues' do
    it 'uses max_threads for the * queue' do
      queues = 'low:1;*'
      connections = GoodJobConnectionPoolSize.num_explicit_threads_from_queues(
        queues: queues,
        max_threads: IdentityConfig.store.good_job_max_threads,
      )

      expect(connections).to eq(IdentityConfig.store.good_job_max_threads + 1)
    end

    it 'sums individual queue sizes' do
      queues = 'low:1;medium:2;high:3;'
      connections = GoodJobConnectionPoolSize.num_explicit_threads_from_queues(
        queues: queues,
        max_threads: IdentityConfig.store.good_job_max_threads,
      )

      expect(connections).to eq(6)
    end
  end
end
