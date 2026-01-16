require 'rails_helper'

RSpec.describe EmailMasker do
  describe '#mask_email' do
    context 'when local portion of email is a single character' do
      it 'replaces with 2 asterisks' do
        expect(described_class.mask('a@example.com')).to eq('**@example.com')
      end
    end

    context 'when local portion of email is two characters long' do
      it 'replaces with 2 asterisks' do
        expect(described_class.mask('ab@example.com')).to eq('**@example.com')
      end
    end

    context 'when local portion of email is three characters long' do
      it 'keeps first and last characters, replaces middle with 2 asterisks' do
        expect(described_class.mask('abc@example.com')).to eq('a**c@example.com')
      end
    end

    context 'when local portion of email is more than 3 characters long' do
      it 'keeps first and last characters, replaces middle with 2 asterisks' do
        expect(described_class.mask('john.doe@example.com')).to eq('j**e@example.com')
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
