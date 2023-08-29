import { usePropertyValue } from '@18f/identity-test-helpers';
import isTrackableErrorEvent from './is-trackable-error-event';

describe('isTrackableErrorEvent', () => {
  context('with filename not present on event', () => {
    const event = new ErrorEvent('error');

    it('returns false', () => {
      expect(isTrackableErrorEvent(event)).to.be.false();
    });
  });

  context('with filename as an invalid url', () => {
    const event = new ErrorEvent('error', { filename: '.' });

    it('returns false', () => {
      expect(isTrackableErrorEvent(event)).to.be.false();
    });
  });

  context('with filename from a different host', () => {
    const event = new ErrorEvent('error', { filename: 'http://different.example.com/foo.js' });

    it('returns false', () => {
      expect(isTrackableErrorEvent(event)).to.be.false();
    });
  });

  context('with filename from the same host', () => {
    const event = new ErrorEvent('error', {
      filename: new URL('foo.js', window.location.origin).toString(),
    });

    it('returns true', () => {
      expect(isTrackableErrorEvent(event)).to.be.true();
    });
  });

  context('with webpack-internal: scheme path', () => {
    const event = new ErrorEvent('error', {
      filename: 'webpack-internal:///./app/javascript/packages/analytics/index.ts',
    });

    context('in environment other than development', () => {
      usePropertyValue(process.env, 'NODE_ENV', 'production');

      it('returns false', () => {
        expect(isTrackableErrorEvent(event)).to.be.false();
      });
    });

    context('in development environment', () => {
      usePropertyValue(process.env, 'NODE_ENV', 'development');

      it('returns true', () => {
        expect(isTrackableErrorEvent(event)).to.be.true();
      });
    });
  });
});
