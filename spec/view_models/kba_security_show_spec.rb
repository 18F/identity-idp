require 'rails_helper'

describe KbaSecurityShow do
  describe '#answers' do
    it 'the first option is a message' do
      answers = KbaSecurityShow.answers
      expect(answers[0][0]).to eq(I18n.t('kba_security.dropdown_message'))
      expect(answers[0][1]).to eq(-1)
    end

    it 'the last option is other' do
      answers = KbaSecurityShow.answers
      expect(answers[-1][0]).to eq(I18n.t('kba_security.dropdown_other'))
      expect(answers[-1][1]).to eq(0)
    end
  end
end
