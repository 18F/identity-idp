import zxcvbn from 'zxcvbn';
import { t } from '@18f/identity-i18n';
import type { ZXCVBNResult, ZXCVBNScore } from 'zxcvbn';

const MINIMUM_STRENGTH: ZXCVBNScore = 3;

const snakeCase = (string: string): string =>
  string.replace(/[ -]/g, '_').replace(/\W/g, '').toLowerCase();

class PasswordStrengthElement extends HTMLElement {
  connectedCallback() {
    this.input.addEventListener('input', () => this.#handleValueChange());
  }

  get strength(): HTMLElement {
    return this.querySelector('.password-strength__strength')!;
  }

  get feedback(): HTMLElement {
    return this.querySelector('.password-strength__feedback')!;
  }

  get input(): HTMLInputElement {
    return this.ownerDocument.getElementById(this.getAttribute('input-id')!) as HTMLInputElement;
  }

  get minimumLength(): number {
    return Number(this.getAttribute('minimum-length')!);
  }

  get forbiddenPasswords(): string[] {
    return JSON.parse(this.getAttribute('forbidden-passwords')!);
  }

  /**
   * Returns a normalized score on zxcvbn's scale. Notably, this artificially lowers a score if it
   * does not meet the minimum length requires, to avoid confusion where an invalid value would
   * display as being a great password.
   *
   * @param result zxcvbn result
   *
   * @return Normalized zxcvbn score
   */
  #getNormalizedScore(result: ZXCVBNResult): ZXCVBNScore {
    const { score } = result;

    if (score >= MINIMUM_STRENGTH && this.input.value.length < this.minimumLength) {
      return Math.max(MINIMUM_STRENGTH - 1, 0) as ZXCVBNScore;
    }

    return score;
  }

  /**
   * Returns true if the input's value is considered valid for submission, or false otherwise.
   *
   * @param result zxcvbn result
   *
   * @return Whether the input's value is valid for submission
   */
  #isValid(result: ZXCVBNResult): boolean {
    return result.score >= MINIMUM_STRENGTH && this.input.value.length >= this.minimumLength;
  }

  /**
   * Given a zxcvbn default feedback string hardcoded in English, returns a localized equivalent
   * string translated to the current language.
   *
   * @param englishFeedback Default feedback string from zxcvbn
   *
   * @return Localized equivalent string translated to the current language
   */
  #getLocalizedFeedback(englishFeedback: string): string {
    // i18n-tasks-use t('zxcvbn.feedback.a_word_by_itself_is_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.add_another_word_or_two_uncommon_words_are_better')
    // i18n-tasks-use t('zxcvbn.feedback.all_uppercase_is_almost_as_easy_to_guess_as_all_lowercase')
    // i18n-tasks-use t('zxcvbn.feedback.avoid_dates_and_years_that_are_associated_with_you')
    // i18n-tasks-use t('zxcvbn.feedback.avoid_recent_years')
    // i18n-tasks-use t('zxcvbn.feedback.avoid_repeated_words_and_characters')
    // i18n-tasks-use t('zxcvbn.feedback.avoid_sequences')
    // i18n-tasks-use t('zxcvbn.feedback.avoid_years_that_are_associated_with_you')
    // i18n-tasks-use t('zxcvbn.feedback.capitalization_doesnt_help_very_much')
    // i18n-tasks-use t('zxcvbn.feedback.common_names_and_surnames_are_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.dates_are_often_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.for_a_stronger_password_use_a_few_words_separated_by_spaces_but_avoid_common_phrases')
    // i18n-tasks-use t('zxcvbn.feedback.names_and_surnames_by_themselves_are_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.no_need_for_symbols_digits_or_uppercase_letters')
    // i18n-tasks-use t('zxcvbn.feedback.predictable_substitutions_like__instead_of_a_dont_help_very_much')
    // i18n-tasks-use t('zxcvbn.feedback.recent_years_are_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.repeats_like_aaa_are_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.repeats_like_abcabcabc_are_only_slightly_harder_to_guess_than_abc')
    // i18n-tasks-use t('zxcvbn.feedback.reversed_words_arent_much_harder_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.sequences_like_abc_or_6543_are_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.short_keyboard_patterns_are_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.straight_rows_of_keys_are_easy_to_guess')
    // i18n-tasks-use t('zxcvbn.feedback.there_is_no_need_for_symbols_digits_or_uppercase_letters')
    // i18n-tasks-use t('zxcvbn.feedback.this_is_a_top_100_common_password')
    // i18n-tasks-use t('zxcvbn.feedback.this_is_a_top_10_common_password')
    // i18n-tasks-use t('zxcvbn.feedback.this_is_a_very_common_password')
    // i18n-tasks-use t('zxcvbn.feedback.this_is_similar_to_a_commonly_used_password')
    // i18n-tasks-use t('zxcvbn.feedback.use_a_few_words_avoid_common_phrases')
    // i18n-tasks-use t('zxcvbn.feedback.use_a_longer_keyboard_pattern_with_more_turns')
    return t(`zxcvbn.feedback.${snakeCase(englishFeedback)}`);
  }

  /**
   * Returns text to be shown as feedback for the current input value, based on the zxcvbn result
   * and other factors such as minimum password length or use of a forbidden password.
   *
   * @param result zxcvbn result
   *
   * @return Localized feedback text
   */
  #getNormalizedFeedback(result: ZXCVBNResult): string | null {
    const { warning, suggestions } = result.feedback;

    if (this.forbiddenPasswords.includes(this.input.value)) {
      return t('errors.attributes.password.avoid_using_phrases_that_are_easily_guessed');
    }

    if (warning) {
      return this.#getLocalizedFeedback(warning);
    }

    if (suggestions.length) {
      return suggestions.map((suggestion) => this.#getLocalizedFeedback(suggestion)).join('. ');
    }

    if (this.input.value.length < this.minimumLength) {
      return t('errors.attributes.password.too_short.other', { count: this.minimumLength });
    }

    return null;
  }

  /**
   * Returns the strength label associated with a given score.
   *
   * @param score Score
   *
   * @return Strength label.
   */
  #getStrengthLabel(score: number): string {
    // i18n-tasks-use t('instructions.password.strength.0')
    // i18n-tasks-use t('instructions.password.strength.1')
    // i18n-tasks-use t('instructions.password.strength.2')
    // i18n-tasks-use t('instructions.password.strength.3')
    // i18n-tasks-use t('instructions.password.strength.4')
    return t(`instructions.password.strength.${score}`);
  }

  /**
   * Updates the current strength and feedback indicators in response to a changed input value.
   */
  #handleValueChange() {
    const hasValue = !!this.input.value;
    this.classList.toggle('display-none', !hasValue);
    this.removeAttribute('score');
    if (hasValue) {
      const result = zxcvbn(this.input.value, this.forbiddenPasswords);
      const score = this.#getNormalizedScore(result);
      this.setAttribute('score', String(score));
      const inputDescribedBy = this.input.getAttribute('aria-describedby');
      if (!inputDescribedBy?.includes('password-strength')) {
        this.input.setAttribute(
          'aria-describedby',
          ['password-strength', inputDescribedBy].join(' '),
        );
      }
      this.input.setCustomValidity(
        this.#isValid(result) ? '' : t('errors.messages.stronger_password'),
      );
      this.strength.textContent = this.#getStrengthLabel(score);
      this.feedback.textContent = this.#getNormalizedFeedback(result);
    } else {
      this.input.setAttribute(
        'aria-describedby',
        this.input.getAttribute('aria-describedby')!.replace(/\s*password-strength\s*/, ''),
      );
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-password-strength': PasswordStrengthElement;
  }
}

if (!customElements.get('lg-password-strength')) {
  customElements.define('lg-password-strength', PasswordStrengthElement);
}

export default PasswordStrengthElement;
