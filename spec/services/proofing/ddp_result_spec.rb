require 'rails_helper'

RSpec.describe Proofing::DdpResult do
  describe '#add_error' do
    shared_examples 'add_error' do |key|
      it 'returns itself' do
        expect(result).to be_an_instance_of(Proofing::DdpResult)
      end

      it 'adds an error under the key' do
        expect(result.errors[key]).to eq([error])
      end

      it 'does not add duplicate error' do
        expect(result.add_error(error).errors[key]).to eq([error])
      end
    end

    let(:error) { 'FOOBAR' }

    context 'with no key' do
      let(:result) { Proofing::DdpResult.new.add_error(error) }
      it_behaves_like 'add_error', :base
    end

    context 'with a key' do
      let(:result) { Proofing::DdpResult.new.add_error(:foo, error) }
      it_behaves_like 'add_error', :foo
    end
  end

  describe '#exception?' do
    subject { result.exception? }

    context 'when there is an exception' do
      let(:result) { Proofing::DdpResult.new(exception: StandardError.new) }
      it { is_expected.to eq(true) }
    end
    context 'when there is no exception' do
      let(:result) { Proofing::DdpResult.new }
      it { is_expected.to eq(false) }
    end
  end

  describe '#failed?' do
    subject { result.failed? }

    context 'when there is an error AND an exception' do
      let(:result) do
        Proofing::DdpResult.new(exception: StandardError.new).add_error('foobar')
      end
      it { is_expected.to eq(false) }
    end

    context 'when there is an error and no exception' do
      let(:result) { Proofing::DdpResult.new.add_error('foobar') }
      it { is_expected.to eq(true) }
    end

    context 'when there is no error' do
      let(:result) { Proofing::DdpResult.new }
      it { is_expected.to eq(false) }
    end
  end

  describe '#success?' do
    subject { result.success? }

    context 'when it is successful' do
      let(:result) { Proofing::DdpResult.new(success: true) }
      it { is_expected.to eq(true) }
    end

    context 'when it is unsuccessful' do
      let(:result) { Proofing::DdpResult.new(success: false) }
      it { is_expected.to eq(false) }
    end
  end

  describe '#timed_out?' do
    subject { result.timed_out? }

    context 'when there is a timeout error' do
      let(:result) { Proofing::DdpResult.new(exception: Proofing::TimeoutError.new) }
      it { is_expected.to eq(true) }
    end

    context 'when there is a generic error' do
      let(:result) { Proofing::DdpResult.new(exception: StandardError.new) }
      it { is_expected.to eq(false) }
    end

    context 'when there is no error' do
      let(:result) { Proofing::DdpResult.new }
      it { is_expected.to eq(false) }
    end
  end

  describe 'context' do
    context 'when provided' do
      it 'is present' do
        context = { foo: 'bar' }
        result = Proofing::DdpResult.new
        result.context = context
        expect(result.context).to eq(context)
      end
    end
  end

  describe 'transaction_id' do
    context 'when provided' do
      it 'is present' do
        transaction_id = 'foo'
        result = Proofing::DdpResult.new
        result.transaction_id = transaction_id
        expect(result.transaction_id).to eq(transaction_id)
      end
    end
  end
end
