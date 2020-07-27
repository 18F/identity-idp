require 'rails_helper'

describe Idv::ImageUploadController do
  describe '#upload' do
    before do
      sign_in_user
    end
    context 'with an invalid content type' do
      it 'raises an error' do
        # WIP
      end
    end
  end
end
