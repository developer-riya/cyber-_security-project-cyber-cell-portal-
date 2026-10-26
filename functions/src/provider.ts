import {Buffer} from "node:buffer";

import {Client} from "undici";

import {
  NormalizedIndicatorRequest,
  ProviderLookupResult,
} from "./types";

const VIRUSTOTAL_ORIGIN = "https://www.virustotal.com";
const MAX_PROVIDER_RESPONSE_BYTES = 512 * 1024;

export interface ProviderTransportResponse {
  readonly statusCode: number;
  readonly contentType?: string;
  readonly body: Buffer;
}

export interface ProviderTransport {
  get(path: string, apiKey: string): Promise<ProviderTransportResponse>;
}

export class VirusTotalHttpsTransport implements ProviderTransport {
  private readonly client = new Client(VIRUSTOTAL_ORIGIN, {
    connectTimeout: 1_000,
    headersTimeout: 2_000,
    bodyTimeout: 2_000,
    pipelining: 0,
  });

  async get(path: string, apiKey: string): Promise<ProviderTransportResponse> {
    if (!path.startsWith("/api/v3/") || path.includes("..")) {
      throw new Error("invalid-provider-path");
    }
    const response = await this.client.request({
      method: "GET",
      path,
      headers: {
        accept: "application/json",
        "x-apikey": apiKey,
      },
    });
    const chunks: Buffer[] = [];
    let size = 0;
    for await (const value of response.body) {
      const chunk = Buffer.isBuffer(value) ? value : Buffer.from(value);
      size += chunk.length;
      if (size > MAX_PROVIDER_RESPONSE_BYTES) {
        response.body.destroy();
        throw new ProviderResponseTooLargeError();
      }
      chunks.push(chunk);
    }
    const header = response.headers["content-type"];
    return {
      statusCode: response.statusCode,
      contentType: Array.isArray(header) ? header[0] : header,
      body: Buffer.concat(chunks, size),
    };
  }
}

export class ProviderResponseTooLargeError extends Error {
  constructor() {
    super("provider-response-too-large");
    this.name = "ProviderResponseTooLargeError";
  }
}

export class VirusTotalProviderClient {
  constructor(
    private readonly transport: ProviderTransport,
    private readonly retryDelay: (milliseconds: number) => Promise<void> =
      (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
  ) {}

  async lookup(
    request: NormalizedIndicatorRequest,
    apiKey: string,
    beforeAttempt: () => Promise<boolean> = async () => true,
  ): Promise<ProviderLookupResult> {
    if (apiKey.length === 0) {
      return {
        status: "NOT_CONFIGURED",
        evidence: [],
        providerStatus: "NOT_CONFIGURED",
        errorCategory: "NOT_CONFIGURED",
      };
    }
    const path = providerPath(request);
    for (let attempt = 0; attempt <= 1; attempt += 1) {
      if (!await beforeAttempt()) {
        return {
          status: "ERROR",
          evidence: ["The request rate limit was reached."],
          providerStatus: "UNAVAILABLE",
          errorCategory: "RATE_LIMITED",
        };
      }
      try {
        const response = await this.transport.get(path, apiKey);
        if (isRetryableStatus(response.statusCode) && attempt === 0) {
          await this.retryDelay(100);
          continue;
        }
        return parseProviderResponse(response);
      } catch (error) {
        if (error instanceof ProviderResponseTooLargeError) {
          return providerError("MALFORMED_RESPONSE");
        }
        if (isTimeoutError(error)) {
          return {
            status: "TIMEOUT",
            evidence: ["The reputation service timed out."],
            providerStatus: "UNAVAILABLE",
            errorCategory: "TIMEOUT",
          };
        }
        if (attempt === 0) {
          await this.retryDelay(100);
          continue;
        }
        return providerError("PROVIDER");
      }
    }
    return providerError("PROVIDER");
  }
}

function providerPath(request: NormalizedIndicatorRequest): string {
  switch (request.operation) {
    case "HASH":
      return `/api/v3/files/${encodeURIComponent(request.indicator)}`;
    case "URL": {
      const urlId = Buffer.from(request.indicator, "utf8").toString("base64url");
      return `/api/v3/urls/${urlId}`;
    }
    case "DOMAIN":
      return `/api/v3/domains/${encodeURIComponent(request.indicator)}`;
    case "IPV4":
    case "IPV6":
      return `/api/v3/ip_addresses/${encodeURIComponent(request.indicator)}`;
  }
}

function parseProviderResponse(
  response: ProviderTransportResponse,
): ProviderLookupResult {
  if (response.statusCode === 404) {
    return {
      status: "UNKNOWN",
      evidence: ["No reputation record was available for this indicator."],
      providerStatus: "AVAILABLE",
    };
  }
  if (response.statusCode === 429) {
    return {
      status: "ERROR",
      evidence: ["The reputation service rate limit was reached."],
      providerStatus: "UNAVAILABLE",
      errorCategory: "RATE_LIMITED",
    };
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return providerError("PROVIDER");
  }
  if (!response.contentType?.toLowerCase().includes("application/json")) {
    return providerError("MALFORMED_RESPONSE");
  }
  let decoded: unknown;
  try {
    decoded = JSON.parse(response.body.toString("utf8"));
  } catch {
    return providerError("MALFORMED_RESPONSE");
  }
  const stats = extractStats(decoded);
  if (stats === undefined) {
    return {
      status: "UNKNOWN",
      evidence: ["The provider did not return completed reputation statistics."],
      providerStatus: "AVAILABLE",
    };
  }
  const total = stats.malicious + stats.suspicious + stats.harmless + stats.undetected;
  if (stats.malicious > 0) {
    return {
      status: "MALICIOUS",
      evidence: [`Reputation analysis reported ${stats.malicious} malicious detection(s).`],
      providerStatus: "AVAILABLE",
    };
  }
  if (stats.suspicious > 0) {
    return {
      status: "SUSPICIOUS",
      evidence: [`Reputation analysis reported ${stats.suspicious} suspicious detection(s).`],
      providerStatus: "AVAILABLE",
    };
  }
  if (total > 0) {
    return {
      status: "CLEAN",
      evidence: ["Completed reputation checks reported no malicious or suspicious detections."],
      providerStatus: "AVAILABLE",
    };
  }
  return {
    status: "UNKNOWN",
    evidence: ["Reputation evidence was insufficient for a conclusion."],
    providerStatus: "AVAILABLE",
  };
}

interface ProviderStats {
  readonly malicious: number;
  readonly suspicious: number;
  readonly harmless: number;
  readonly undetected: number;
}

function extractStats(value: unknown): ProviderStats | undefined {
  if (!isRecord(value) || !isRecord(value.data) ||
      !isRecord(value.data.attributes) ||
      !isRecord(value.data.attributes.last_analysis_stats)) {
    return undefined;
  }
  const raw = value.data.attributes.last_analysis_stats;
  const fields = ["malicious", "suspicious", "harmless", "undetected"] as const;
  if (fields.some((field) => !isSafeCount(raw[field]))) return undefined;
  return {
    malicious: raw.malicious as number,
    suspicious: raw.suspicious as number,
    harmless: raw.harmless as number,
    undetected: raw.undetected as number,
  };
}

function isSafeCount(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 && value <= 1_000_000;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isRetryableStatus(status: number): boolean {
  return status === 502 || status === 503 || status === 504;
}

function isTimeoutError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  return error.name === "AbortError" || error.name === "HeadersTimeoutError" ||
    error.name === "BodyTimeoutError" || error.name === "ConnectTimeoutError";
}

function providerError(
  errorCategory: "PROVIDER" | "MALFORMED_RESPONSE",
): ProviderLookupResult {
  return {
    status: "ERROR",
    evidence: ["Threat intelligence was unavailable; local analysis remains available."],
    providerStatus: "UNAVAILABLE",
    errorCategory,
  };
}
