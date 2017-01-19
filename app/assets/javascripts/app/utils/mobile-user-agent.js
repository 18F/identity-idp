const mobileDeviceAgents = [
  'Android',
  'webOS',
  'iPhone',
  'iPad',
  'iPod',
  'BlackBerry',
  'IEMobile',
  'Opera Mini',
];

const userAgentsString = (accumulator, deviceName, index) => {
  /* eslint-disable no-param-reassign */
  accumulator += (!index ? deviceName : `|${deviceName}`);

  return accumulator;
};

const mobileDevicesRegExp = new RegExp(mobileDeviceAgents.reduce(userAgentsString, ''), 'i');

const isMobileUserAgent = userAgent =>
  mobileDevicesRegExp.test(userAgent);


export { mobileDeviceAgents };
export default isMobileUserAgent;
