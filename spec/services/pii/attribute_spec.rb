require 'rails_helper'

describe Pii::Attribute do
  let(:first_name_utf8) { 'José' }
  let(:first_name_ascii) { 'Jose' }

  subject { described_class.new(raw: first_name_utf8) }

  describe '#ascii' do
    it 'transliterates' do
      expect(subject.ascii).to eq first_name_ascii
    end
  end

  # rubocop:disable UnneededInterpolation
  describe 'delegation' do
    it 'delegates to raw' do
      expect(subject.blank?).to eq false
      expect(subject.present?).to eq true
      expect(subject.to_s).to eq first_name_utf8
      expect(subject.to_str).to eq first_name_utf8
      expect("#{subject}").to eq first_name_utf8
      expect(subject).to eq first_name_utf8
    end
  end
  # rubocop:enable UnneededInterpolation
end
