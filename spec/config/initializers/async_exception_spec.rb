require 'rails_helper'

RSpec.describe 'async_error' do
  let(:enabled) { false }
  subject do
    load Rails.root.join('config', 'initializers', 'async_exception.rb').to_s
  end

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls).and_return(enabled)
  end

  context 'async uploads are not enabled' do
    it 'does not raise an error' do
      expect { subject }.not_to raise_error
    end
  end

  context 'async uploads are enabled' do
    let(:enabled) { true }

    it 'does raise an error' do
      expect { subject }.to raise_error
    end
  end
end
