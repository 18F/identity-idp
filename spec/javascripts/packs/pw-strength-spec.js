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

    it('returns an empty result for empty password', () => {
      const z = zxcvbn('');

      expect(getFeedback(z)).to.equal(EMPTY_RESULT);
    });

    it('returns an empty result for a strong password', () => {
      const z = zxcvbn('!Juq2Uk2**RBEsA8');

      expect(getFeedback(z)).to.equal(EMPTY_RESULT);
    });

    it('returns feedback for a weak password', () => {
      const z = zxcvbn('password');

      expect(getFeedback(z)).to.equal('zxcvbn.feedback.this_is_a_top_10_common_password');
    });
  });
});
