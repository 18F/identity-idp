require 'rails_helper'

RSpec.describe Idv::PhonePresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper

  let(:gpo_letter_available) { false }
  let(:proofing_with_superior_evidence) { false }

  subject do
    described_class.new(
      gpo_letter_available:,
      proofing_with_superior_evidence:,
      url_options: {},
    )
  end

  describe '#heading' do
    context 'when proofing with superior evidence is true' do
      let(:proofing_with_superior_evidence) { true }

      it 'returns title.idv.phone_skip_verification translation text' do
        expect(subject.heading).to eq(t('titles.idv.phone_skip_verification'))
      end
    end

    context 'when proofing with superior evidence is false' do
      let(:proofing_with_superior_evidence) { false }

      it 'returns title.idv.phone translation text' do
        expect(subject.heading).to eq(t('titles.idv.phone'))
      end
    end
  end

  describe '#description' do
    context 'when proofing with superior evidence is true' do
      let(:proofing_with_superior_evidence) { true }

      it 'returns idv.messages.phone.description_skip_verification translation text' do
        expect(subject.description).to eq(t('idv.messages.phone.description_skip_verification'))
      end
    end

    context 'when proofing with superior evidence is false' do
      let(:proofing_with_superior_evidence) { false }

      it 'returns idv.messages.phone.description translation text' do
        expect(subject.description).to eq(t('idv.messages.phone.description'))
      end
    end
  end

  describe '#troubleshooting_options' do
    context 'when gpo letter available is true' do
      let(:gpo_letter_available) { true }

      it 'returns an array with verify by mail troubleshooting options' do
        expect(subject.troubleshooting_options).to eq(
          [
            { url: idv_request_letter_path, text: t('idv.troubleshooting.options.verify_by_mail') },
          ],
        )
      end
    end

    context 'when gpo letter available is false' do
      let(:gpo_letter_available) { false }

      it 'returns an empty array' do
        expect(subject.troubleshooting_options).to eq([])
      end
    end
  end

  describe '#phone_failure_alert_body' do
    context 'when gpo letter available is true' do
      let(:gpo_letter_available) { true }

      it 'returns idv.messages.phone.failed_number.gpo_verify_link' do
        expect(subject.phone_failure_alert_body).to eq(
          t(
            'idv.messages.phone.failed_number.gpo_alert_html',
            link_html: link_to(
              t('idv.messages.phone.failed_number.gpo_verify_link'),
              idv_request_letter_path,
            ),
          ),
        )
      end
    end

    context 'when gpo letter available is false' do
      let(:gpo_letter_available) { false }

      it 'returns an empty array' do
        expect(subject.phone_failure_alert_body).to eq(
          t('idv.messages.phone.failed_number.try_again_html'),
        )
      end
    end
  end
end
