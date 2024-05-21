require 'rails_helper'

RSpec.describe 'asset subresource integrity' do
  let(:load_path) { Rails.application.assets.resolver.resolve(logical_path) }
  let(:content) { Rails.application.assets.resolver.read(logical_path) }
  let(:link_header) { response.headers['link'] }
  let(:rendered_digest) { link_header.match(%r{<#{load_path}[^,]+integrity=([^,]+)})[1] }
  let(:expected_digest) { "sha256-#{Digest::SHA256.base64digest(content)}" }

  before { get root_url }

  ['init.js'].each do |path|
    describe path do
      let(:logical_path) { path }

      it { expect(rendered_digest).to eq(expected_digest) }
    end
  end
end
