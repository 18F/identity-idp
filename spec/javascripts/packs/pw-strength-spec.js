import zxcvbn from 'zxcvbn';
import { getForbiddenPasswords, getFeedback } from '../../../app/javascript/packs/pw-strength';

describe('pw-strength', () => {
  describe('getForbiddenPasswords', () => {
    it('returns empty array if given argument is null', () => {
      const element = null;
      const result = getForbiddenPasswords(element);

      expect(result).to.deep.equal([]);
    });

    it('returns empty array if element has absent dataset value', () => {
      const element = document.createElement('span');
      const result = getForbiddenPasswords(element);

      expect(result).to.deep.equal([]);
    });

    it('returns empty array if element has invalid dataset value', () => {
      const element = document.createElement('span');
      element.setAttribute('data-forbidden', 'nil');
      const result = getForbiddenPasswords(element);

      expect(result).to.deep.equal([]);
    });

    it('parsed array of forbidden passwords', () => {
      const element = document.createElement('span');
      element.setAttribute('data-forbidden', '["foo","bar","baz"]');
      const result = getForbiddenPasswords(element);

      expect(result).to.be.deep.equal(['foo', 'bar', 'baz']);
    });
  });

  describe('getFeedback', () => {
    const EMPTY_RESULT = '&nbsp;';
    const shortPasswordResults = {
      password: '_3G%JMyR"',
      guesses: 1000000001,
      guesses_log10: 9.000000000434293,
      sequence: [
        {
          pattern: 'bruteforce',
          token: '_3G%JMyR"',
          i: 0,
          j: 8,
          guesses: 1000000000,
          guesses_log10: 8.999999999999998,
        },
      ],
      calc_time: 3,
      crack_times_seconds: {
        online_throttling_100_per_hour: 36000000036,
        online_no_throttling_10_per_second: 100000000.1,
        offline_slow_hashing_1e4_per_second: 100000.0001,
        offline_fast_hashing_1e10_per_second: 0.1000000001,
      },
      crack_times_display: {
        online_throttling_100_per_hour: 'centuries',
        online_no_throttling_10_per_second: '3 years',
        offline_slow_hashing_1e4_per_second: '1 day',
        offline_fast_hashing_1e10_per_second: 'less than a second',
      },
      score: 2,
      feedback: { warning: '', suggestions: [] },
    };

    it('returns an empty result for empty password', () => {
      const z = zxcvbn('');

      expect(getFeedback(z, { minimumLength: 12 })).to.equal(EMPTY_RESULT);
    });

    it('returns an empty result for a strong password', () => {
      const z = zxcvbn('!Juq2Uk2**RBEsA8');

      expect(getFeedback(z, { minimumLength: 12 })).to.equal(EMPTY_RESULT);
    });

    it('returns feedback for a weak password', () => {
      const z = zxcvbn('password');

      expect(getFeedback(z, { minimumLength: 12 })).to.equal(
        'zxcvbn.feedback.this_is_a_top_10_common_password',
      );
    });

    it('shows feedback when a password is too short', () => {
      const minPasswordLength = 12;

      expect(getFeedback(shortPasswordResults, { minimumLength: minPasswordLength })).to.equal(
        'errors.attributes.password.too_short.other',
        { count: minPasswordLength },
      );
    });
  });
});
