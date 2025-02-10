require 'rails_helper'

RSpec.describe RobotsController do
  describe '#index' do
    subject(:response) { get :index }
    let(:lines) { response.body.lines(chomp: true) }

    it 'renders plaintext' do
      expect(response.content_type.split(';').first).to eq('text/plain')
    end

    it 'targets all crawlers' do
      expect(lines).to include('User-agent: *')
    end

    it 'denies all by default' do
      expect(lines).to include('Disallow: /')
    end

    it 'allows public routes' do
      expect(lines).to include('Allow: /$')
    end

    it 'allows localized version of public routes' do
      expect(lines).to include('Allow: /es$')
    end
  end
end
