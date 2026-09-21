/**
 * Base URL of the auth backend.
 *
 * Override per environment with `VITE_API_URL`; the fallback keeps local
 * development working with no `.env` file present.
 */
export const API_BASE_URL =
  import.meta.env.VITE_API_URL ?? "http://localhost:8001";

/**
 * Backend URL embedded in mobile pairing links. It may differ from the URL
 * used by this browser; Android emulators reach the host through 10.0.2.2.
 */
export const MOBILE_API_BASE_URL =
  import.meta.env.VITE_MOBILE_API_URL ?? API_BASE_URL;

/** Builds an absolute backend URL from a leading-slash path. */
export const apiUrl = (path: string) => `${API_BASE_URL}${path}`;

/**
 * Envelope that `ResponseHandler` on the backend wraps every response in.
 * Note there is no `success` field — `code` is 0 on success, -1 on failure.
 */
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
  url: string;
}
