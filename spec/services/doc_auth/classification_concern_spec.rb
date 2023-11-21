require 'rails_helper'

RSpec.describe DocAuth::ClassificationConcern do
  let(:class_name) { 'Identification Card' }
  let(:country_code) { 'USA' }
  let(:issuer_type) { 'StateProvince' }
  let(:info) do
    {
      Front: {
        ClassName: class_name,
        CountryCode: country_code,
        IssuerType: issuer_type,
      },
      Back: {
        ClassName: class_name,
        CountryCode: country_code,
        IssuerType: issuer_type,
      },
    }
  end

  subject do
    Class.new do
      include DocAuth::ClassificationConcern
      attr_reader :classification_info
      def initialize(classification_info)
        @classification_info = classification_info
      end
    end.new(info)
  end

  describe '#id_type_supported?' do
    context 'with state issued identification card' do
      it 'returns true' do
        expect(subject.id_type_supported?).to eq(true)
      end
    end

    context 'with US passport card' do
      let(:issuer_type) { 'Country' }
      it 'returns false' do
        expect(subject.id_type_supported?).to eq(false)
      end
    end

    context 'with state issued drivers license' do
      let(:class_name) { 'Drivers License' }
      it 'returns true' do
        expect(subject.id_type_supported?).to eq(true)
      end
    end
  end
end
