require 'rails_helper'

describe RescueCodesController do
  describe 'before_actions' do
    it 'includes required before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  describe '#format_code' do
    it 'includes a hyphen in the middle of the string' do
      result = RescueCodesController.format_code('12345678')
      expect(result[4]).to eq('-')
    end
  end

  describe '#plain_text_codes' do
    before do
      codes = ['1234-5678', '2468-3690']
      @body = RescueCodesController.plain_text_codes(codes, 'test@test.com')
    end

    it 'contains the codes' do
      expect(@body).to include('1234-5678')
    end
  end
end
