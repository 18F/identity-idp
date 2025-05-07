require 'rails_helper'

RSpec.describe EmailMasker do
  describe '#mask_email' do
    context 'when email is a single character' do
      it 'replaces with a single asterisk' do
        masker = described_class.new(email: "a@example.com")
        expect(masker.mask_email).to eq("*@example.com")
      end
    end

    context 'when email is a two characters' do
      it 'replaces with two asterisks' do
        masker = described_class.new(email: "ab@example.com")
        expect(masker.mask_email).to eq("**@example.com")
      end
    end

    context 'when email is a three characters' do
      it 'keeps first and last characters, replaces middle with asterisk' do
        masker = described_class.new(email: "abc@example.com")
        expect(masker.mask_email).to eq("a*c@example.com")
      end
    end

    context 'when email has long characters' do
      it 'keeps first and last characters, replaces middle with asterisks' do
        masker = described_class.new(email: "john.doe@example.com")
        expect(masker.mask_email).to eq("j******e@example.com")
      end
    end


    context 'with invalid email format' do
      it 'returns the original string without masking if no @ symbol' do
        masker = described_class.new(email: "invalidemail")
        expect(masker.mask_email).to eq("invalidemail")
      end

      it 'handles empty email string' do
        masker = described_class.new(email: "")
        expect(masker.mask_email).to eq("")
      end
    end

    context 'with nil email' do
      it 'raises NoMethodError' do
        expect {
          described_class.new(email: nil).mask_email
        }.to raise_error(NoMethodError)
      end
    end
  end
end