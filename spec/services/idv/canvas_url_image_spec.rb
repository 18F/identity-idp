require 'rails_helper'

describe Idv::CanvasUrlImage do
  include DocAuthHelper

  subject { described_class.new(doc_auth_image_canvas_url) }

  describe 'content_type' do
    it 'returns the content type from the header' do
      expect(subject.content_type).to eq('image/jpeg')
    end
  end

  describe 'read' do
    it 'returns the data associated with the image' do
      expect(subject.read).to eq(doc_auth_image_canvas_data)
    end
  end
end
