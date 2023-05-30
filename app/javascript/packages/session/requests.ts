import { request } from '@18f/identity-request';

export interface SessionStatusResponse {
  /**
   * Whether the session is still active.
   */
  live: boolean;

  /**
   * ISO8601-formatted date string for session timeout.
   */
  timeout: string;
}

export interface SessionStatus {
  /**
   * Whether the session is still active.
   */
  isLive: boolean;

  /**
   * ISO8601-formatted date string for session timeout.
   */
  timeout: string;
}

export const STATUS_API_ENDPOINT = '/active';
export const KEEP_ALIVE_API_ENDPOINT = '/sessions/keepalive';

const mapSessionStatusResponse = ({ live, timeout }: SessionStatusResponse): SessionStatus => ({
  isLive: live,
  timeout,
});

/**
 * Request the current session status. Returns a promise resolving to the current session status.
 *
 * @return A promise resolving to the current session status
 */
export const requestSessionStatus = (): Promise<SessionStatus> =>
  request<SessionStatusResponse>(STATUS_API_ENDPOINT)
    .catch(() => ({ live: false, timeout: new Date().toISOString() }))
    .then(mapSessionStatusResponse);

/**
 * Request that the current session be kept alive. Returns a promise resolving to the updated
 * session status.
 *
 * @return A promise resolving to the updated session status.
 */
export const extendSession = (): Promise<SessionStatus> =>
  request<SessionStatusResponse>(KEEP_ALIVE_API_ENDPOINT, { method: 'POST' }).then(
    mapSessionStatusResponse,
  );
