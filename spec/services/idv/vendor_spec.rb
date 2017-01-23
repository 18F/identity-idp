require 'rails_helper'

describe Idv::Vendor do
  describe '#pick' do
    context 'test env' do
      it 'returns :mock' do
        expect(subject.pick).to eq :mock
      end
    end

    context 'production env' do
      before do
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(Figaro.env).to receive(:proofing_vendors).and_return('foo bar')
      end

      it 'returns random from env var' do
        expect(subject.pick).to_not eq :mock
        expect([:foo, :bar]).to include(subject.pick)
      end
    end
  end

  describe '#available' do
    before do
      allow(Figaro.env).to receive(:proofing_vendors).and_return('foo bar')
    end

    it 'returns array of symbolized values from env var' do
      expect(subject.available).to eq [:foo, :bar]
    end
  end

  describe '#update_env_vars' do
    before do
      allow(Figaro.env).to receive(:proofing_vendors).and_return('foo')
      stub_const 'ENV', ENV.to_h.merge('foo_thing' => 'some value')
    end

    it 'sets UPPER case equivalue of existing ENV var' do
      expect(ENV['FOO_THING']).to eq nil

      subject.upcase_env_vars

      expect(ENV['foo_thing']).to eq 'some value'
      expect(ENV['FOO_THING']).to eq 'some value'
    end
  end
end
