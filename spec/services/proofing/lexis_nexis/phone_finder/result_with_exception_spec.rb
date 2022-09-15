require 'rails_helper'

RSpec.describe Proofing::LexisNexis::PhoneFinder::ResultWithException do
  let(:exception) { StandardError.new('test message') }

  subject { described_class.new(exception) }

  describe '#timed_out?' do
    context 'with a timeout error' do
      let(:exception) { Proofing::TimeoutError.new('hi') }

      it { expect(subject.timed_out?).to eq(true) }
    end

    context 'with a error that is not a timeout error' do
      let(:exception) { StandardError.new('test message') }

      it { expect(subject.timed_out?).to eq(false) }
    end
  end

  describe '#to_h' do
    it 'returns a hash verion of the result' do
      expect(subject.to_h).to eq(
        success: false,
        errors: {},
        exception: exception,
        timed_out: false,
        vendor_name: 'lexisnexis:phone_finder',
      )
    end
  end
end
