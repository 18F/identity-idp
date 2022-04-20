require 'rails_helper'

RSpec.describe Digest::Instance do
  describe '#urlsafe_base64digest' do
    it 'is the URL-safe version of a base64 digest' do
      base64 = Digest::SHA256.base64digest('aaa')

      urlsafe = Digest::SHA256.urlsafe_base64digest('aaa')

      expect(urlsafe).to eq(base64.tr('+/', '-_').tr('=', ''))
    end
  end
end
