require 'rails_helper'

RSpec.describe EmailMasker do
  describe '#mask_email' do
    context 'when email is a single character' do
      it 'replaces with a single asterisk' do
        expect(described_class.mask('a@example.com')).to eq('*@example.com')
      end
    end

    context 'when email is a two characters' do
      it 'replaces with two asterisks' do
        expect(described_class.mask('ab@example.com')).to eq('**@example.com')
      end
    end

    context 'when email is a three characters' do
      it 'keeps first and last characters, replaces middle with asterisk' do
        expect(described_class.mask('abc@example.com')).to eq('a*c@example.com')
      end
    end

    context 'when email has long characters' do
      it 'keeps first and last characters, replaces middle with asterisks' do
        expect(described_class.mask('john.doe@example.com')).to eq('j******e@example.com')
      end
    end

    context 'with invalid email format' do
      it 'returns the original string without masking if no @ symbol' do
        expect(described_class.mask('invalidemail')).to eq('invalidemail')
      end

      it 'handles empty email string' do
        expect(described_class.mask('')).to eq('')
      end
    end

    context 'with nil email' do
      it 'raises NoMethodError' do
        expect do
          described_class.mask(nil)
        end.to raise_error(NoMethodError)
      end
    end
  end
end
