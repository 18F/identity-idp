require 'spec_helper'

RSpec.describe Idv::ApiImageUploadForm do
  subject(:form) do
    Idv::ApiImageUploadForm.new(
      {
        front: front_image,
        back: back_image,
        selfie: selfie_image,
      },
      liveness_checking_enabled: liveness_checking_enabled?
    )
  end

  let(:liveness_checking_enabled?) { true }
  let(:red_dot_png_image_uri) do
    <<-EOS.gsub(/\s/, '')
      data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA
      AAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO
      9TXL0Y4OHwAAAABJRU5ErkJggg==
    EOS
  end

  let(:front_image) { red_dot_png_image_uri }
  let(:back_image) { red_dot_png_image_uri }
  let(:selfie_image) { red_dot_png_image_uri }

  describe '#valid?' do
    context 'with all valid images' do
      it 'is valid' do
        expect(form.valid?).to eq(true)
        expect(form.errors).to be_blank
      end
    end

    context 'with valid front and back but no selfie' do
      let(:selfie_image) { nil }

      context 'with liveness required' do
        let(:liveness_checking_enabled?) { true }

        it 'is not valid' do
          expect(form.valid?).to eq(false)
          expect(form.errors[:selfie]).to eq(['Please fill in this field.'])
        end
      end

      context 'without liveness require' do
        let(:liveness_checking_enabled?) { false }

        it 'is valid' do
          expect(form.valid?).to eq(true)
          expect(form.errors).to be_blank
        end
      end
    end

    context 'when an image data URI is not a properly encoded image' do
      let(:selfie_image) { 'http://cool.com' }

      it 'is not valid' do
        expect(form.valid?).to eq(false)
        expect(form.errors[:selfie]).to eq(['invalid image url'])
      end
    end
  end
end
