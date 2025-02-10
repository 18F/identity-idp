require 'rails_helper'

RSpec.describe SsnFormatter do
  describe '.format' do
    let(:ssn) { '' }
    subject { SsnFormatter.format(ssn) }

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

  describe '.format_masked' do
    let(:ssn) { '' }
    subject { SsnFormatter.format_masked(ssn) }

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

  describe '.normalize' do
    let(:ssn) { '' }
    subject { SsnFormatter.normalize(ssn) }

    context 'numeric' do
      let(:ssn) { 123456789 }

      it { should eq('123456789') }
    end

    context 'string with dashes' do
      let(:ssn) { '123-45-6789' }

      it { should eq('123456789') }
    end

    context 'numeric string' do
      let(:ssn) { '123456789' }

      it { should eq('123456789') }
    end
  end
end
