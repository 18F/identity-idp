require 'rails_helper'

RSpec.describe Idv::ProofingAgent::FailureEmailUserSet do
  subject { described_class.new }
  let(:key) { described_class::KEY }

  after do
    REDIS_POOL.with do |client|
      client.del(key) # empty set after each test
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

    context 'when the uuid does not exist' do
      it 'adds a uuid with the current unix timestamp as the zscore to the set' do
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1, with_scores: true) }).to eq(
          [[user_uuid, current_time.to_i]],
        )
      end
    end

    context 'when the uuid already exists' do
      let(:future_time) { Time.zone.now + 1.hour }

      before do
        travel_to(future_time) do
          subject.add(user_uuid)
        end
      end

      it "updates the uuid's zscore with the current unix timestamp" do
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1, with_scores: true) }).to eq(
          [[user_uuid, future_time.to_i]],
        )
      end
    end
  end

  describe '#find_by_time_range' do
    let(:user_uuid) { Faker::Internet.uuid }
    let(:current_time) { Time.zone.now }
    let(:max_time) { (current_time + 20.minutes).to_i }
    let(:min_time) { (current_time - 1.hour).to_i }

    context 'when uuids exist' do
      before do
        freeze_time
        travel_to(time_added) do
          subject.add(user_uuid)
        end
      end

      context "when a uuid's timestamp is between time range" do
        let(:time_added) { current_time }

        it 'returns members' do
          expect(subject.find_by_time_range(min_time, max_time)).to eq([user_uuid])
        end
      end

      context "when a uuid's timestamp is not between time range" do
        let(:time_added) { current_time + 2.hours }

        it 'returns an empty array' do
          expect(subject.find_by_time_range(min_time, max_time)).to eq([])
        end
      end
    end

    context 'when no uuids exist' do
      it 'returns an empty array' do
        expect(subject.find_by_time_range(min_time, max_time)).to eq([])
      end
    end
  end

  describe '#remove' do
    let(:user_uuid) { Faker::Internet.uuid }

    before do
      subject.add(user_uuid)
    end

    context 'when the uuid is present in the set' do
      it 'removes the uuid from the set' do
        subject.remove(user_uuid)
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1) }).to eq([])
      end

      it 'returns true' do
        expect(subject.remove(user_uuid)).to be(true)
      end
    end

    context 'when the uuid is not present in the set' do
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

  describe '#remove_uuids' do
    let(:user_uuids) { Array.new(3) { Faker::Internet.uuid } }

    before do
      user_uuids.each do |uuid|
        subject.add(uuid)
      end
    end

    context 'when the uuids are present in the set' do
      it 'removes the uuids from the set' do
        subject.remove_uuids(user_uuids)
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1) }).to eq([])
      end
    end

    context 'when a subset of the uuids are present in the set' do
      it 'removes the uuids from the set' do
        subject.remove_uuids([user_uuids[0], user_uuids[2]])
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1) }).to eq([user_uuids[1]])
      end
    end

    context 'when the uuids are not present in the set' do
      let(:non_existing_user_uuids) { ['1234'] }

      it 'does not remove a uuid from the set' do
        subject.remove_uuids(non_existing_user_uuids)
        expect(REDIS_POOL.with { |client| client.zrange(key, 0, -1) }).to include(*user_uuids)
      end
    end

    context 'when the uuids array is empty' do
      it 'returns 0' do
        expect(subject.remove_uuids([])).to eq(0)
      end
    end
  end
end
