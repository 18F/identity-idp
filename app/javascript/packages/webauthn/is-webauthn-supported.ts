export type IsWebauthnSupported = () => boolean;

const isWebauthnSupported: IsWebauthnSupported = () => !!navigator.credentials;

export default isWebauthnSupported;
