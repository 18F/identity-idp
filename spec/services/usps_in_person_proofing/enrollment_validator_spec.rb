require 'rails_helper'

RSpec.describe UspsInPersonProofing::EnrollmentValidator do
    let (:transliterator) { UspsInPersonProofing::Transliterator.new }
    let (:sut) { UspsInPersonProofing::EnrollmentValidator.new(transliterator) }

    describe '#validate' do
        context 'baseline functionality' do
            it 'does not require any fields' do
                expect(sut.validate({})).to be_nil
            end
            it 'calls the transliterator once per field' do
                expect(transliterator).to receive(:transliterate).
                    with('First').once.and_call_original
                expect(transliterator).to receive(:transliterate).
                    with('Last').once.and_call_original
                expect(transliterator).to receive(:transliterate).
                    with('Addr1').once.and_call_original
                expect(transliterator).to receive(:transliterate).
                    with('Addr2').once.and_call_original
                expect(transliterator).to receive(:transliterate).
                    with('MyCity').once.and_call_original
                sut.validate({
                    first_name: 'First',
                    last_name: 'Last',
                    address1: 'Addr1',
                    address2: 'Addr2',
                    city: 'MyCity',
                })
            end
            it 'uses the original string for unsupported characters replaced by transliteration' do
                expect(sut.validate({
                    last_name: 'TИbleЉs',
                })).to eq(
                    last_name: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.name',
                        char_list: 'Љ, И',
                    ),
                )
            end
            it 'uses the transliteration replacement character if it was part of the original string' do
                replace_char = UspsInPersonProofing::Transliterator::REPLACEMENT
                expect(sut.validate({
                    first_name: "TИb#{replace_char}leЉs",
                })).to eq(
                    first_name: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.name',
                        char_list: "#{replace_char}, Љ, И",
                    ),
                )
            end
            it 'does not duplicate characters in the lists returned' do
                expect(sut.validate({
                    address1: 'TИИИbleЉs',
                })).to eq(
                    address1: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.address',
                        char_list: 'Љ, И',
                    ),
                )
            end
            it 'returns nil when no errors occurred' do
                expect(sut.validate({
                    first_name: 'First',
                    last_name: 'Last',
                    address1: 'Addr1',
                    address2: 'Addr2',
                    city: 'MyCity',
                })).to be_nil
            end
        end
        context 'specific fields' do
            it 'uses the correct translations for validation errors' do
                expect(sut.validate({
                    first_name: 'first ДЉ',
                    last_name: 'last ЉѲ',
                    address1: 'a1 ѮИ',
                    address2: 'a2 ЉѺ',
                    city: 'city ЧИ',
                })).to eq(
                    first_name: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.name',
                        char_list: 'Љ, Д',
                    ),
                    last_name: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.name',
                        char_list:'Љ, Ѳ',
                    ),
                    address1: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.address',
                        char_list:'И, Ѯ',
                    ),
                    address2: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.address',
                        char_list:'Љ, Ѻ',
                    ),
                    city: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.address',
                        char_list: 'И, Ч',
                    ),
                )
            end
            it 'rejects post-transliteration characters that fail additional validation' do
                expect(sut.validate({
                    first_name: "Fi\u02bb rst-1#/.",
                    last_name: "La\u02bb st-1#/.",
                    address1: "Here-\u201cTh3r3\u201d\u02bbs / #Any.where!",
                    address2: "Here-\u201cTh3r3\u201d\u02bbs / #Any.where!",
                    city: "Ci\u02bb ty-1#/.",
                })).to eq(
                    first_name: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.name',
                        char_list: '#, ., /, 1',
                    ),
                    last_name: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.name',
                        char_list: '#, ., /, 1',
                    ),
                    address1: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.address',
                        char_list:'!, "',
                    ),
                    address2: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.address',
                        char_list:'!, "',
                    ),
                    city: I18n.t(
                        'in_person_proofing.form.state_id.errors.unsupported_chars.address',
                        char_list: '#, ., /, 1',
                    ),
                )
            end
        end
    end
end