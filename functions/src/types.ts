export type ThreatIntelligenceOperation =
  | "HASH"
  | "URL"
  | "DOMAIN"
  | "IPV4"
  | "IPV6";

export type ThreatIntelligenceStatus =
  | "MALICIOUS"
  | "SUSPICIOUS"
  | "CLEAN"
  | "UNKNOWN"
  | "NOT_CONFIGURED"
  | "ERROR"
  | "TIMEOUT";

export type ThreatIntelligenceErrorCategory =
  | "AUTHENTICATION"
  | "APP_CHECK"
  | "VALIDATION"
  | "RATE_LIMITED"
  | "PROVIDER"
  | "MALFORMED_RESPONSE"
  | "TIMEOUT"
  | "NOT_CONFIGURED";

export interface NormalizedIndicatorRequest {
  readonly operation: ThreatIntelligenceOperation;
  readonly indicator: string;
  readonly transmittedValueType:
    | "SHA256"
    | "NORMALIZED_URL"
    | "DOMAIN"
    | "IP";
}

export interface ThreatIntelligencePrivacyResponse {
  readonly rawContentTransmitted: false;
  readonly transmittedValueType: NormalizedIndicatorRequest["transmittedValueType"];
  readonly privacyMode: "INDICATOR_ONLY";
}

export interface ThreatIntelligenceProxyResponse {
  readonly operation: ThreatIntelligenceOperation;
  readonly status: ThreatIntelligenceStatus;
  readonly evidence: readonly string[];
  readonly providerStatus: "AVAILABLE" | "UNAVAILABLE" | "NOT_CONFIGURED";
  readonly durationMs: number;
  readonly cache: { readonly hit: boolean };
  readonly privacy: ThreatIntelligencePrivacyResponse;
  readonly errorCategory?: ThreatIntelligenceErrorCategory;
}

export interface ProviderLookupResult {
  readonly status: ThreatIntelligenceStatus;
  readonly evidence: readonly string[];
  readonly providerStatus: "AVAILABLE" | "UNAVAILABLE" | "NOT_CONFIGURED";
  readonly errorCategory?: ThreatIntelligenceErrorCategory;
}

export interface VerifiedRequestIdentity {
  readonly uid: string;
  readonly appId?: string;
}

export interface RuntimeSecurityConfiguration {
  readonly enabled: boolean;
  readonly requireAppCheck: boolean;
  readonly providerApiKey: string;
}
