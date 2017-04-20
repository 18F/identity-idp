require 'rails_helper'

describe HealthCheck::CheckerJob do
  describe '#perform' do
    context 'queue is alive' do
      it 'sets the queue name to alive' do
        redis = IdentityIdp.redis
        queue = 'queue_name'
        redis.set(queue, nil)

        HealthCheck::CheckerJob.set(queue: queue).perform_now(queue)

        expect(redis.get(queue)).to eq 'alive'
      end
    end
  end
end
