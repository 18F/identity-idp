require 'rails_helper'

describe Idv::Acuant::AssureId do
  let(:subject) { Idv::Acuant::FakeAssureId.new }
  let(:instance_id) { '3899aab2-1da7-4e64-8c31-238f279663fc' }
  let(:good_acuant_back_image_status) { [true, { 'Result' => 1 }] }
  let(:good_acuant_front_image_status) { [true, ''] }
  let(:image_data) { 'abc' }

  describe '#create_document' do
    it 'returns a good status with an instance id' do
      result = subject.create_document

      expect(result).to eq([true, instance_id])
      expect(subject.instance_id).to eq(instance_id)
    end
  end

  describe '#post_front_image' do
    it 'returns a good status' do
      result = subject.post_front_image(image_data)

      expect(result).to eq(good_acuant_front_image_status)
    end
  end

  describe '#post_back_image' do
    it 'returns a good status' do
      result = subject.post_back_image(image_data)

      expect(result).to eq(good_acuant_back_image_status)
    end
  end

  describe '#results' do
    it 'returns a good status' do
      result = subject.results

      expect(result[0]).to eq(true)
      results = result[1]
      expect(results['Fields']).to be_present
      expect(results['Result']).to eq(1)
    end
  end
end
