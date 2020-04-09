require 'rails_helper'

describe MobileCaptureController do
  describe '#new' do
    it 'works' do
      get :new

      expect(response).to_not be_redirect
    end
  end
end
