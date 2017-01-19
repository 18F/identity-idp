import isMobileUserAgent from 'app/utils/mobile-user-agent';
import { mobileDeviceAgents } from 'app/utils/mobile-user-agent';

describe('#isMobileUserAgent', () => {
  it('returns true if user agent is perscribed mobile devices', () => {
    mobileDeviceAgents.forEach((device) => {
      expect(isMobileUserAgent(device)).to.be.true();
    });
  });

  it('returns false otherwise', () => {
    expect(isMobileUserAgent('Chrome')).to.be.false();
    expect(isMobileUserAgent('Firefox')).to.be.false();
    expect(isMobileUserAgent('Opera M')).to.be.false();
  });
});
