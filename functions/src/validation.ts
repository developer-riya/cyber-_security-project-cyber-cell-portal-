import {isIP} from "node:net";

import {
  NormalizedIndicatorRequest,
  ThreatIntelligenceOperation,
} from "./types";

const MAX_INDICATOR_LENGTH = 2_048;
const DOMAIN_LABEL = /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/;
const DISALLOWED_HOST_SUFFIXES = [".local", ".localhost", ".internal"];

export class RequestValidationError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "RequestValidationError";
  }
}

export function validateIndicatorRequest(body: unknown): NormalizedIndicatorRequest {
  if (!isRecord(body)) throw new RequestValidationError("invalid-json-object");
  const keys = Object.keys(body).sort();
  const expected = ["indicator", "indicatorType", "provider"];
  if (keys.length !== expected.length || keys.some((key, index) => key !== expected[index])) {
    throw new RequestValidationError("unknown-or-missing-field");
  }
  if (body.provider !== "virustotal-premium") {
    throw new RequestValidationError("invalid-provider");
  }
  if (typeof body.indicatorType !== "string" || typeof body.indicator !== "string") {
    throw new RequestValidationError("invalid-field-type");
  }
  if (body.indicator.length === 0 || body.indicator.length > MAX_INDICATOR_LENGTH) {
    throw new RequestValidationError("invalid-indicator-length");
  }

  switch (body.indicatorType) {
    case "sha256":
      return validateHash(body.indicator);
    case "url":
      return validateUrl(body.indicator);
    case "domain":
      return validateDomain(body.indicator);
    case "ip":
      return validateIp(body.indicator);
    default:
      throw new RequestValidationError("unsupported-operation");
  }
}

function validateHash(indicator: string): NormalizedIndicatorRequest {
  if (!/^[a-fA-F0-9]{64}$/.test(indicator)) {
    throw new RequestValidationError("invalid-sha256");
  }
  return {
    operation: "HASH",
    indicator: indicator.toLowerCase(),
    transmittedValueType: "SHA256",
  };
}

function validateUrl(indicator: string): NormalizedIndicatorRequest {
  let url: URL;
  try {
    url = new URL(indicator);
  } catch {
    throw new RequestValidationError("invalid-url");
  }
  if ((url.protocol !== "https:" && url.protocol !== "http:") ||
      url.username.length > 0 ||
      url.password.length > 0 ||
      url.hostname.length === 0 ||
      url.hash.length > 0) {
    throw new RequestValidationError("invalid-url");
  }
  validatePublicHost(url.hostname);
  url.hostname = url.hostname.toLowerCase();
  return {
    operation: "URL",
    indicator: url.toString(),
    transmittedValueType: "NORMALIZED_URL",
  };
}

function validateDomain(indicator: string): NormalizedIndicatorRequest {
  const domain = indicator.toLowerCase();
  validatePublicHost(domain);
  if (isIP(stripIpv6Brackets(domain)) !== 0) {
    throw new RequestValidationError("ip-supplied-as-domain");
  }
  return {
    operation: "DOMAIN",
    indicator: domain,
    transmittedValueType: "DOMAIN",
  };
}

function validateIp(indicator: string): NormalizedIndicatorRequest {
  const unwrapped = stripIpv6Brackets(indicator).toLowerCase();
  const version = isIP(unwrapped);
  if (version === 0 || !isPublicIp(unwrapped, version)) {
    throw new RequestValidationError("invalid-or-private-ip");
  }
  return {
    operation: version === 4 ? "IPV4" : "IPV6",
    indicator: version === 4 ? normalizeIpv4(unwrapped) : normalizeIpv6(unwrapped),
    transmittedValueType: "IP",
  };
}

function validatePublicHost(rawHost: string): void {
  const host = stripIpv6Brackets(rawHost).toLowerCase();
  const ipVersion = isIP(host);
  if (ipVersion !== 0) {
    if (!isPublicIp(host, ipVersion)) {
      throw new RequestValidationError("private-or-reserved-host");
    }
    return;
  }
  if (host.length > 253 || host === "localhost" || !host.includes(".") ||
      DISALLOWED_HOST_SUFFIXES.some((suffix) => host.endsWith(suffix))) {
    throw new RequestValidationError("invalid-or-private-host");
  }
  const labels = host.split(".");
  if (labels.some((label) => !DOMAIN_LABEL.test(label))) {
    throw new RequestValidationError("invalid-hostname");
  }
}

function isPublicIp(ip: string, version: number): boolean {
  if (version === 4) {
    const [a, b, c] = ip.split(".").map(Number);
    return !(a === 0 || a === 10 || a === 127 ||
      (a === 100 && b >= 64 && b <= 127) ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      (a === 192 && b === 0 && c === 0) ||
      (a === 192 && b === 0 && c === 2) ||
      (a === 192 && b === 88 && c === 99) ||
      (a === 198 && (b === 18 || b === 19)) ||
      (a === 198 && b === 51 && c === 100) ||
      (a === 203 && b === 0 && c === 113) ||
      a >= 224);
  }
  const normalized = ip.toLowerCase();
  const firstSegment = Number.parseInt(normalized.split(":", 1)[0], 16);
  return Number.isFinite(firstSegment) &&
    firstSegment >= 0x2000 && firstSegment <= 0x3fff &&
    !normalized.startsWith("2001:db8:");
}

function normalizeIpv4(ip: string): string {
  return ip.split(".").map((part) => String(Number(part))).join(".");
}

function normalizeIpv6(ip: string): string {
  const hostname = new URL(`http://[${ip}]/`).hostname;
  return stripIpv6Brackets(hostname).toLowerCase();
}

function stripIpv6Brackets(value: string): string {
  return value.startsWith("[") && value.endsWith("]") ? value.slice(1, -1) : value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function operationName(operation: ThreatIntelligenceOperation): string {
  return operation;
}
