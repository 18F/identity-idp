# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DocAuth::Mock::TrueIdHttpResponseBuilder' do
  let(:template_file) { 'true_id_response_success_3.json' }
  let(:subject) do
    DocAuth::Mock::TrueIdHttpResponseBuilder.new(
      templatefile: template_file,
      selfie_check_enabled: true,
    )
  end

  let(:empty_yaml) do
    <<~YAML
    YAML
  end

  let(:input_with_alerts) do
    <<~YAML
      doc_auth_result: Passed
      document:
        city: Bayside
        state: NY
        zipcode: '11364'
        dob: 10/06/1938
        phone: +1 314-555-1212
        state_id_jurisdiction: 'ND'
        state_id_expiration: 10/10/2016
        state_id_type: Identification Card
        issuing_country_code: USA
      failed_alerts:
        - name: 2D Barcode Read
          result: Attention
    YAML
  end
  describe '#available_checks' do
    it 'returns array of checks' do
      result = subject.available_checks
      expect(result).to be_kind_of(Hash)
    end
  end
  context 'when change the builder for response' do
    it 'succeeds to change' do
      status = subject.get_check_status('2D Barcode Read')
      expect(status).to eq('Attention')
      subject.use_uploaded_file(input_with_alerts)
      expect(subject.set_check_status('2D Barcode Read', 'Failed')).to be_truthy
      subject.set_expire_date(DateTime.now - 1.year)
      status = subject.get_check_status('Document Expired')
      expect(status).to eq('Failed')
      status = subject.get_check_status('2D Barcode Read')
      expect(status).to eq('Failed')
    end
  end

  describe 'with a yaml file as input' do
    it 'applies the change in the yaml' do
      subject.use_uploaded_file(input_with_alerts)
      status = subject.get_check_status('2D Barcode Read')
      expect(status).to eq('Attention')
    end

    it 'has no error with empty yaml' do
      subject.use_uploaded_file(empty_yaml)
      status = subject.get_check_status('2D Barcode Read')
      expect(status).to eq('Attention')
    end
  end
end
