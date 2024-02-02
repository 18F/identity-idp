# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DocAuth::Mock::TrueIdHttpResponseBuilder' do
  let(:template_file) { 'true_id_response_success_3.json' }
  let(:subject) do
    DocAuth::Mock::TrueIdHttpResponseBuilder.new(templatefile: template_file)
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
      failed_alerts:
        - name: 2D Barcode Read
          result: Attention
      classification_info:
        Front:
          ClassName: Drivers License
          CountryCode: USA
        Back:
          ClassName: Drivers License
          CountryCode: USA
    YAML
  end
  before do
    # Do nothing
  end

  after do
    # Do nothing
  end

  context 'when condition' do
    it 'succeeds to change' do
      expect(subject).to be_truthy
      subject.use_uploaded_file(input_with_alerts)
      expect(subject.set_alert_result('2D Barcode Read', 'Attention')).to be_truthy
      subject.set_doc_auth_result('Passed')
      subject.set_doc_auth_result('Attention')
      subject.set_doc_auth_result('Pass')
    end
  end
end
