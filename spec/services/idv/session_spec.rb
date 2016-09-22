require 'rails_helper'

describe Idv::Session do
  let(:user) { User.new }
  let(:user_session) { {} }

  subject { described_class.new(user_session, user) }

  describe '#method_missing' do
    it 'disallows un-supported attributes' do
      expect { subject.foo = 'bar' }.to raise_error NoMethodError
    end

    it 'allows supported attributes' do
      subject.vendor = 'bar'

      expect(subject.vendor).to eq 'bar'
    end
  end
end
