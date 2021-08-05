require 'rails_helper'

describe SsnFormatter do
  describe '#format' do
    let(:mask) { false }
    let(:ssn) { '' }
    subject(:masked_text) { SsnFormatter.format(ssn, mask: mask) }

    context 'no mask' do
      let(:mask) { false }

      context 'numeric' do
        let(:ssn) { 123456789 }

        it { should eq('123-45-6789') }
      end

      context 'string with dashes' do
        let(:ssn) { '123-45-6789' }

        it { should eq('123-45-6789') }
      end

      context 'numeric string' do
        let(:ssn) { '123456789' }

        it { should eq('123-45-6789') }
      end
    end

    context 'mask' do
      let(:mask) { true }

      context 'numeric' do
        let(:ssn) { 123456789 }

        it { should eq('1**-**-***9') }
      end

      context 'string with dashes' do
        let(:ssn) { '123-45-6789' }

        it { should eq('1**-**-***9') }
      end

      context 'numeric string' do
        let(:ssn) { '123456789' }

        it { should eq('1**-**-***9') }
      end
    end
  end
end
