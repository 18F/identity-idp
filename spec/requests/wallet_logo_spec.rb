require 'rails_helper'

RSpec.describe 'Wallet logos' do
  describe 'dark mode logo' do
    let(:logo_path) { '/images/login-gov-logo-dark.png' }

    it 'is available' do
      get logo_path
      expect(response.status).to eq(200)
      expect(response.content_type).to eq('image/png')
    end

    it 'meets the wallet specifications (aspect ratio and size)' do
      get logo_path
      data = response.body
      width, height = data[16..23].unpack('N2')

      expect(width).to be >= 660
      expect(height).to be >= 660
      expect(width).to eq(height)
    end
  end

  describe 'light mode logo' do
    let(:logo_path) { '/images/login-gov-logo-light.png' }

    it 'is available' do
      get logo_path
      expect(response.status).to eq(200)
      expect(response.content_type).to eq('image/png')
    end

    it 'meets the wallet specifications (aspect ratio and size)' do
      get logo_path
      data = response.body
      width, height = data[16..23].unpack('N2')

      expect(width).to be >= 660
      expect(height).to be >= 660
      expect(width).to eq(height)
    end
  end
end
