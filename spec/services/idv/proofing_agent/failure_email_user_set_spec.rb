require 'rails_helper'

RSpec.describe Idv::ProofingAgent::FailureEmailUserSet do
  subject { described_class.new }
  let(:key) { described_class::KEY }

  before do
    REDIS_POOL.with do |client|
      client.del(key) # empty set before each test
    end
  end

  after do
    REDIS_POOL.with do |client|
      client.del(key) # empty set before each test
    end
  end

  describe '#add' do
    let(:user_uuid) { Faker::Internet.uuid }
    let(:current_time) { Time.zone.now }

    before do
      freeze_time
      travel_to(current_time) do
        subject.add(user_uuid)
      end
    end

    context 'when the member does not exist' do
      it 'adds a uuid member with a unix timestamp as the zscore to the set' do
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1, with_scores: true) }).to eq(
          [[user_uuid, current_time.to_i]],
        )
      end
    end

    context 'when the member already exists' do
      let(:future_time) { Time.zone.now + 1.hour }

      before do
        travel_to(future_time) do
          subject.add(user_uuid)
        end
      end

      it "updates the uuid member's zscore with the current unix timestamp" do
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1, with_scores: true) }).to eq(
          [[user_uuid, future_time.to_i]],
        )
      end
    end
  end

  describe '#remove' do
    let(:user_uuid) { Faker::Internet.uuid }

    before do
      subject.add(user_uuid)
    end

    context 'when the value is present in the set' do
      it 'removes the uuid from the set' do
        subject.remove(user_uuid)
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1) }).to eq([])
      end

      it 'returns true' do
        expect(subject.remove(user_uuid)).to be(true)
      end
    end

    context 'when the value is not present in the set' do
      let(:non_existing_user_uuid) { '1234' }

      it 'does not remove a uuid from the set' do
        subject.remove(non_existing_user_uuid)
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1) }).to eq([user_uuid])
      end

      it 'returns false' do
        expect(subject.remove(non_existing_user_uuid)).to be(false)
      end
    end
  end
end
