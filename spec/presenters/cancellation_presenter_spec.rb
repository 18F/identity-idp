require 'rails_helper'

describe CancellationPresenter do
  let(:good_url) { 'http://example.com/asdf/qwerty' }
  let(:good_url_with_path) { 'http://example.com/asdf?qwerty=123' }
  let(:bad_url) { 'http://evil.com/asdf/qwerty' }

  subject { described_class.new(referer: referer_header, url_options: {}) }

  describe '#go_back_link' do
    let(:sign_up_path) { '/authentication_methods_setup' }

    context 'without a referer header' do
      let(:referer_header) { nil }

      it 'returns the sign_up_path' do
        expect(subject.go_back_path).to eq(sign_up_path)
      end
    end

    context 'with a referer header' do
      let(:referer_header) { 'http://www.example.com/asdf/qwerty' }

      it 'returns the path' do
        expect(subject.go_back_path).to eq('/asdf/qwerty')
      end
    end

    context 'with a referer header with query params' do
      let(:referer_header) { 'http://www.example.com/asdf?qwerty=123' }

      it 'returns the path with the query params' do
        expect(subject.go_back_path).to eq('/asdf?qwerty=123')
      end
    end

    context 'with a referer header for a different domain' do
      let(:referer_header) { 'http://www.evil.com/asdf/qwerty' }

      it 'returns the sign_up_path' do
        expect(subject.go_back_path).to eq(sign_up_path)
      end
    end

    context 'with a referer header with a javascript scheme' do
      let(:referer_header) { 'javascript://do-some-evil-stuff' }

      it 'returns the sign_up_path' do
        expect(subject.go_back_path).to eq(sign_up_path)
      end
    end
  end
end
