require 'rails_helper'

RSpec.describe Idv::InPerson::VerifyInfoPresenter do
  let(:enrollment) { create(:in_person_enrollment, :establishing) }

  subject { described_class.new(enrollment: enrollment) }

  describe '#step_indicator_steps' do
    it 'returns the IPP step indicator steps' do
      expect(subject.step_indicator_steps).to eq(
        Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_IPP,
      )
    end
  end

  describe '#identity_info_partial' do
    context 'when enrollment is a passport enrollment' do
      let(:enrollment) { create(:in_person_enrollment, :establishing, :passport_book) }

      subject { described_class.new(enrollment: enrollment) }

      it 'returns "passport_section"' do
        expect(subject.identity_info_partial).to eq('passport_section')
      end
    end

    context 'when enrollment is not passport enrollment' do
      let(:enrollment) { create(:in_person_enrollment, :establishing, :state_id) }

      subject { described_class.new(enrollment: enrollment) }

      it 'returns "state_id_section"' do
        expect(subject.identity_info_partial).to eq('state_id_section')
      end
    end
  end

  describe '#show_state_id_expiration?' do
    [true, false].each do |flag|
      context "when the feature flag is #{flag}" do
        before do
          allow(IdentityConfig.store)
            .to receive(:in_person_proofing_expiration_edge_cases_enabled).and_return(flag)
        end

        it "returns #{flag}" do
          expect(subject.show_state_id_expiration?).to eq(flag)
        end
      end
    end
  end

  describe '#formatted_state_id_expiration' do
    def formatted(value)
      subject.formatted_state_id_expiration(state_id_expiration: value)
    end

    it 'returns nil when the value is blank' do
      expect(formatted(nil)).to be_nil
      expect(formatted('')).to be_nil
    end

    it 'returns the localized label for each sentinel' do
      expect(formatted('military')).to eq(
        I18n.t('in_person_proofing.form.state_id.expiration_date_options.military'),
      )
      expect(formatted('indefinite')).to eq(
        I18n.t('in_person_proofing.form.state_id.expiration_date_options.indefinite'),
      )
      expect(formatted('none')).to eq(
        I18n.t('in_person_proofing.form.state_id.expiration_date_options.other'),
      )
    end

    it 'returns the literal placeholder dates verbatim' do
      expect(formatted('9999-99-99')).to eq('99/99/9999')
      expect(formatted('0000-00-00')).to eq('00/00/0000')
    end

    it 'returns a localized formatted date for a real date' do
      expect(formatted('2030-05-01')).to eq(
        I18n.l(Date.parse('2030-05-01'), format: I18n.t('time.formats.event_date')),
      )
    end
  end
end
