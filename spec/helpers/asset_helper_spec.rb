require 'rails_helper'

RSpec.describe AssetHelper do
  include AssetHelper

  describe 'design_system_asset_path' do
    let(:path) { 'img/example.png' }

    subject(:asset_path) { design_system_asset_path(path) }

    it 'produces an asset path' do
      expect(asset_path).to eq('identity-style-guide/dist/assets/img/example.png')
    end

    context 'with leading slash' do
      let(:path) { '/img/example.png' }

      it 'produces an asset path' do
        expect(asset_path).to eq('identity-style-guide/dist/assets/img/example.png')
      end
    end
  end
end
