import { request } from '@18f/identity-request';

export interface SessionLiveStatusResponse {
  /**
   * Whether the session is still active.
   */
  live: true;

  /**
   * ISO8601-formatted date string for session timeout.
   */
  timeout: string;
}

export interface SessionTimedOutStatusResponse {
  /**
   * Whether the session is still active.
   */
  live: false;

  /**
   * ISO8601-formatted date string for session timeout.
   */
  timeout: null;
}

type SessionStatusResponse = SessionLiveStatusResponse | SessionTimedOutStatusResponse;

interface SessionLiveStatus {
  /**
   * Whether the session is still active.
   */
  isLive: true;

  /**
   * ISO8601-formatted date string for session timeout.
   */
  timeout: Date;
}

interface SessionTimedOutStatus {
  /**
   * Whether the session is still active.
   */
  isLive: false;

  /**
   * ISO8601-formatted date string for session timeout.
   */
  timeout?: undefined;
}

export type SessionStatus = SessionLiveStatus | SessionTimedOutStatus;

export const STATUS_API_ENDPOINT = '/active';
export const KEEP_ALIVE_API_ENDPOINT = '/sessions/keepalive';

function mapSessionStatusResponse<R extends SessionLiveStatusResponse>(
  response: R,
): SessionLiveStatus;
function mapSessionStatusResponse<R extends SessionTimedOutStatusResponse>(
  response: R,
): SessionTimedOutStatus;
function mapSessionStatusResponse<R extends SessionStatusResponse>({
  live,
  timeout,
}: R): SessionLiveStatus | SessionTimedOutStatus {
  return live ? { isLive: true, timeout: new Date(timeout) } : { isLive: false };
}

/**
 * Request the current session status. Returns a promise resolving to the current session status.
 *
 * @return A promise resolving to the current session status
 */
export const requestSessionStatus = (): Promise<SessionStatus> =>
  request<SessionStatusResponse>(STATUS_API_ENDPOINT)
    .catch(() => ({ live: false, timeout: null }))
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
