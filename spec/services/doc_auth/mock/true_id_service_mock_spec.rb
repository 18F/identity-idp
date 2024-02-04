# frozen_string_literal: true

require 'rails_helper'

class DummyTrueIDService
  include DocAuth::Mock::TrueIdServiceMock

  def initialize(config)
    @config = config
  end

  def config
    @config
  end
end
RSpec.describe 'DocAuth::Mock::TrueIDServiceMock' do
  let(:warn_notifier) { instance_double('Proc') }
  let(:config) do
    DocAuth::Mock::Config.new(
      dpi_threshold: 290,
      sharpness_threshold: 40,
      glare_threshold: 40,
      warn_notifier: warn_notifier,
    )
  end
  let(:service) { DummyTrueIDService.new(config) }

  let(:input_with_alerts) do
    <<~YAML
      doc_auth_result: Attention
      document:
        city: Bayside
        state: NY
        zipcode: '11364'
        dob: 10/06/1938
        phone: +1 314-555-1212
        state_id_jurisdiction: 'ND'
        state_id_type: Identification Card
        issuing_country_code: USA
      failed_alerts:
        - name: 2D Barcode Read
          result: Attention
    YAML
  end
  let(:input_id_expired) do
    <<~YAML
      doc_auth_result: Failed
      document:
        city: Bayside
        state: NY
        zipcode: '11364'
        dob: 10/06/1938
        phone: +1 314-555-1212
        state_id_jurisdiction: 'ND'
        state_id_expiration: 10/06/1938
        state_id_type: Identification Card
        issuing_country_code: USA
    YAML
  end

  describe '#post_image' do
    context 'with bar code attention' do
      it 'succeeds to generate response indicate it' do
        response = service.post_images(
          front_image: input_with_alerts,
          back_image: input_with_alerts,
        )
        expect(response.attention_with_barcode?).to eq(true)
        expect(response.successful_result?).to eq(true)
        expect(response.doc_auth_success?).to eq(false)
        expect(response.error_messages).to eq({})
      end
    end

    context 'without expired id' do
      it 'return failed response with expired id error' do
        allow(warn_notifier).to receive(:call)
        response = service.post_images(
          front_image: input_id_expired,
          back_image: input_id_expired,
        )
        expect(response.attention_with_barcode?).to eq(false)
        expect(response.successful_result?).to eq(false)
        expect(response.doc_auth_success?).to eq(false)
        expect(response.error_messages[:general]).to eq(['doc_expired_check'])
        expect(response.error_messages[:front]).to eq(['fallback_field_level'])
        expect(response.error_messages[:back]).to eq(['fallback_field_level'])
      end
    end
  end
end
