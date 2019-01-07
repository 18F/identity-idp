require 'rails_helper'

describe Idv::Acuant::AssureId do
  let(:subject) { Idv::Acuant::AssureId.new }
  let(:instance_id) { '123' }
  let(:acuant_result_2) { '{"Result":2,"Alerts":[{"Actions":"Check the document"}]}' }
  let(:good_acuant_status) { [true, '{"Result":1}'] }
  let(:bad_acuant_status) { [false, ''] }
  let(:good_http_status) { { status: 200, body: '{"Result":1}' } }
  let(:failure_alerts_status) { { status: 200, body: acuant_result_2 } }
  let(:bad_http_status) { { status: 441, body: '' } }
  let(:acuant_base_url) { 'https://example.com' }
  let(:image_data) { 'abc' }

  describe '#create_document' do
    let(:path) { '/AssureIDService/Document/Instance' }

    it 'returns a good status with an instance id' do
      stub_request(:post, acuant_base_url + path).to_return(status: 200, body: instance_id)

      result = subject.create_document

      expect(result).to eq([true, instance_id])
      expect(subject.instance_id).to eq(instance_id)
    end

    it 'returns a bad status' do
      stub_request(:post, acuant_base_url + path).to_return(bad_http_status)

      result = subject.create_document

      expect(result).to eq(bad_acuant_status)
    end
  end

  describe '#post_front_image' do
    let(:side) { Idv::Acuant::AssureId::FRONT }
    let(:path) { "/AssureIDService/Document/#{subject.instance_id}/Image?side=#{side}&light=0" }

    before do
      subject.instance_id = instance_id
    end

    it 'returns a good status' do
      stub_request(:post, acuant_base_url + path).to_return(good_http_status)

      result = subject.post_front_image(image_data)

      expect(result).to eq(good_acuant_status)
    end

    it 'returns a bad status' do
      stub_request(:post, acuant_base_url + path).to_return(bad_http_status)

      result = subject.post_front_image(image_data)

      expect(result).to eq(bad_acuant_status)
    end
  end

  describe '#post_back_image' do
    let(:side) { Idv::Acuant::AssureId::BACK }
    let(:path) { "/AssureIDService/Document/#{subject.instance_id}/Image?side=#{side}&light=0" }

    before do
      subject.instance_id = instance_id
    end

    it 'returns a good status' do
      stub_request(:post, acuant_base_url + path).to_return(good_http_status)

      result = subject.post_back_image(image_data)

      expect(result).to eq(good_acuant_status)
    end

    it 'returns a bad status' do
      stub_request(:post, acuant_base_url + path).to_return(bad_http_status)

      result = subject.post_back_image(image_data)

      expect(result).to eq(bad_acuant_status)
    end
  end

  describe '#results' do
    let(:path) { "/AssureIDService/Document/#{subject.instance_id}" }

    before do
      subject.instance_id = instance_id
    end

    it 'returns a good status' do
      stub_request(:get, acuant_base_url + path).to_return(status: 200, body: '{}')

      result = subject.results

      expect(result).to eq([true, {}])
    end

    it 'returns a bad status' do
      stub_request(:get, acuant_base_url + path).to_return(bad_http_status)

      result = subject.results

      expect(result).to eq(bad_acuant_status)
    end

    it 'returns failure alerts for acuant result=2' do
      stub_request(:get, acuant_base_url + path).to_return(failure_alerts_status)

      result = subject.results

      expect(result).to eq([true, JSON.parse(acuant_result_2)])
    end
  end

  describe '#face_image' do
    let(:path) { "/AssureIDService/Document/#{subject.instance_id}/Field/Image?key=Photo" }

    before do
      subject.instance_id = instance_id
    end

    it 'returns a good status' do
      stub_request(:get, acuant_base_url + path).to_return(good_http_status)

      result = subject.face_image

      expect(result).to eq(good_acuant_status)
    end

    it 'returns a bad status' do
      stub_request(:get, acuant_base_url + path).to_return(bad_http_status)

      result = subject.face_image

      expect(result).to eq(bad_acuant_status)
    end
  end
end
