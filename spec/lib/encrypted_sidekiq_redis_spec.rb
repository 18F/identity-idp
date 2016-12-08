require 'rails_helper'

describe EncryptedSidekiqRedis do
  let(:key) { 'test-queue' }
  let(:value) { 'some random string' }

  subject { EncryptedSidekiqRedis.new(url: Figaro.env.redis_url) }

  before do
    subject.flushall
  end

  describe '#new' do
    it 'takes same options as Redis.new' do
      expect(subject.ping).to eq 'PONG'
    end
  end

  describe 'encryption' do
    it 'encrypts strings pushed to redis' do
      subject.lpush(key, value)

      raw_value = subject.redis.blpop(key).last

      expect(raw_value).to_not eq value
      expect(raw_value).to match 'cipher'
    end
  end

  describe 'decryption' do
    it 'decrypts transparently' do
      subject.lpush(key, value)

      pulled_value = subject.blpop(key).last

      expect(pulled_value).to eq value
    end
  end

  describe '#zrem' do
    it 'modifies value string in-place' do
      subject.zadd(key, 1, value)

      raw_value = subject.zrangebyscore(key, 0, 1, limit: [0, 1]).first

      expect(raw_value).to_not eq value
      expect(subject.zrem(key, raw_value)).to eq true
      expect(raw_value).to eq value
    end
  end
end
