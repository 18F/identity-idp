import zxcvbn from 'zxcvbn';
import { t } from '@18f/identity-i18n';

// zxcvbn returns a strength score from 0 to 4
// we map those scores to:
// 1. a CSS class to the pw strength module
// 2. text describing the score
const scale = {
  0: ['pw-very-weak', t('instructions.password.strength.i')],
  1: ['pw-weak', t('instructions.password.strength.ii')],
  2: ['pw-so-so', t('instructions.password.strength.iii')],
  3: ['pw-good', t('instructions.password.strength.iv')],
  4: ['pw-great', t('instructions.password.strength.v')],
};

const snakeCase = (string) => string.replace(/[ -]/g, '_').replace(/\W/g, '').toLowerCase();

// fallback if zxcvbn lookup fails / field is empty
const fallback = ['pw-na', '...'];

function clearErrors() {
  const x = document.getElementsByClassName('error-message');
  if (x.length > 0) {
    x[0].innerHTML = '';
  }
}

function getStrength(z) {
  // override the strength value to 2 if the password is < 12
  if (!(z && z.password.length && z.password.length >= 12)) {
    if (z.score >= 3) {
      z.score = 2;
    }
  }
  return z && z.password.length ? scale[z.score] : fallback;
}

export function getFeedback(z) {
  if (!z || !z.password || z.score > 2) {
    return '&nbsp;';
  }

  const { warning, suggestions } = z.feedback;

  function lookup(str) {
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
    return t(`zxcvbn.feedback.${snakeCase(str)}`);
  }

  if (!warning && !suggestions.length) {
    return '&nbsp;';
  }
  if (warning) {
    return lookup(warning);
  }

  return `${suggestions.map((s) => lookup(s)).join('. ')}`;
}

function disableSubmit(submitEl, length = 0, score = 0) {
  if (!submitEl) {
    return;
  }

  if (score < 3 || length < 12) {
    submitEl.setAttribute('disabled', true);
  } else {
    submitEl.removeAttribute('disabled');
  }
}

/**
 * @param {HTMLElement?} element
 *
 * @return {string[]}
 */
export function getForbiddenPasswords(element) {
  try {
    return JSON.parse(element.dataset.forbidden);
  } catch {
    return [];
  }
}

function analyzePw() {
  const { userAgent } = window.navigator;
  const input = document.querySelector('.password-toggle__input');
  const pwCntnr = document.getElementById('pw-strength-cntnr');
  const pwStrength = document.getElementById('pw-strength-txt');
  const pwFeedback = document.getElementById('pw-strength-feedback');
  const submit = document.querySelector('input[type="submit"]');
  const forbiddenPasswordsElement = document.querySelector('[data-forbidden]');
  const forbiddenPasswords = getForbiddenPasswords(forbiddenPasswordsElement);

  disableSubmit(submit);

  // the pw strength module is hidden by default ("display-none" CSS class)
  // (so that javascript disabled browsers won't see it)
  // thus, first step is unhiding it
  pwCntnr.className = '';

  function checkPasswordStrength(e) {
    const z = zxcvbn(e.target.value, forbiddenPasswords);
    const [cls, strength] = getStrength(z);
    const feedback = getFeedback(z);
    pwCntnr.className = cls;
    pwStrength.innerHTML = strength;
    pwFeedback.innerHTML = feedback;

    clearErrors();
    disableSubmit(submit, z.password.length, z.score);
  }

  if (/(msie 9)/i.test(userAgent)) {
    input.addEventListener('keyup', checkPasswordStrength);
  }

  input.addEventListener('input', checkPasswordStrength);
}

document.addEventListener('DOMContentLoaded', analyzePw);
