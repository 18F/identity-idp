require 'rails_helper'

RSpec.describe GoBackHelper do
  include GoBackHelper

  describe '#go_back_path' do
    let(:referer) { nil }
    let(:request) { double('request', referer: referer) }

    before do
      allow(helper).to receive(:request).and_return(request)
    end

    subject { go_back_path }

    context 'no referer' do
      let(:referer) { nil }

      it 'is nil' do
        expect(subject).to be_nil
      end
    end

    context 'referer is invalid scheme' do
      let(:referer) { 'javascript:alert()' }

      it 'is nil' do
        expect(subject).to be_nil
      end
    end

    context 'referer from different domain' do
      let(:referer) { 'https://www.gsa.gov/' }

      it 'is nil' do
        expect(subject).to be_nil
      end
    end

    context 'referer from same domain' do
      let(:referer) { 'https://www.gsa.gov/' }

      before do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('www.gsa.gov')
      end

      it 'is path from referer' do
        expect(subject).to eq('/')
      end
    end
  end

  describe '#extract_path_and_query_from_uri' do
    it 'preserves query parameter and path from uri' do
      uri = URI.parse('https://www.gsa.gov/path/to/?with_params=true')
      extracted = extract_path_and_query_from_uri(uri)

      expect(extracted).to eq('/path/to/?with_params=true')
    end
  end

  describe '#app_host' do
    let(:domain_name) { nil }

    before do
      allow(IdentityConfig.store).to receive(:domain_name).and_return(domain_name)
    end

    subject { app_host }

    context 'without port' do
      let(:domain_name) { 'www.gsa.gov' }

      it 'returns host' do
        expect(subject).to eq('www.gsa.gov')
      end
    end

    context 'with port' do
      let(:domain_name) { 'localhost:8000' }

      it 'returns host' do
        expect(subject).to eq('localhost')
      end
    end
  end
end
