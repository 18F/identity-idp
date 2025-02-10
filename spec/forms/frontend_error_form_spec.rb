require 'rails_helper'

RSpec.describe FrontendErrorForm do
  subject(:form) { described_class.new }

  before do
    allow(IdentityConfig.store).to receive(:domain_name).and_return('example.com')
  end

  describe '#submit' do
    subject(:result) { form.submit(filename:, error_id:) }
    let(:error_id) { nil }
    let(:filename) { 'https://example.com/foo.js' }

    context 'with valid filename' do
      let(:filename) { 'https://example.com/foo.js' }

      it 'is successful' do
        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
      end
    end

    context 'without filename' do
      let(:filename) { nil }

      context 'without error id' do
        it 'is unsuccessful' do
          expect(result.success?).to eq(false)
          expect(result.errors).to eq(filename: [t('errors.general'), t('errors.general')])
        end
      end

      context 'with error id' do
        let(:error_id) { 'exampleId' }

        it 'is successful' do
          expect(result.success?).to eq(true)
          expect(result.errors).to eq({})
        end
      end
    end

    context 'with filename without extension' do
      let(:filename) { 'https://example.com/foo' }

      it 'is unsuccessful' do
        expect(result.success?).to eq(false)
        expect(result.errors).to eq(filename: [t('errors.general')])
      end
    end

    context 'with filename having extension other than js' do
      let(:filename) { 'https://example.com/foo.txt' }

      it 'is unsuccessful' do
        expect(result.success?).to eq(false)
        expect(result.errors).to eq(filename: [t('errors.general')])
      end
    end

    context 'with filename from a different host' do
      let(:filename) { 'https://wrong.example.com/foo.js' }

      it 'is unsuccessful' do
        expect(result.success?).to eq(false)
        expect(result.errors).to eq(filename: [t('errors.general')])
      end
    end

    context 'with filename that cannot be parsed as url' do
      let(:filename) { '{' }

      it 'is unsuccessful' do
        expect(result.success?).to eq(false)
        expect(result.errors).to eq(filename: [t('errors.general'), t('errors.general')])
      end
    end
  end
end
