require 'rails_helper'

describe CancellationPresenter do
  let(:good_url) { 'http://example.com/asdf/qwerty' }
  let(:good_url_with_path) { 'http://example.com/asdf?qwerty=123' }
  let(:bad_url) { 'http://evil.com/asdf/qwerty' }

  let(:view_context) { ActionView::Base.new }

  subject { described_class.new(view_context: view_context) }

  describe '#go_back_link' do
    let(:sign_up_path) { '/two_factor_options' }

    before do
      allow(view_context).to receive(:sign_up_path).and_return(sign_up_path)
      request = instance_double(ActionDispatch::Request)
      allow(request).to receive(:env).and_return('HTTP_REFERER' => referer_header)
      allow(view_context).to receive(:request).and_return(request)
    end

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
