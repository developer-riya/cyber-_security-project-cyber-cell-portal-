import {getAppCheck} from "firebase-admin/app-check";
import {getAuth} from "firebase-admin/auth";

import {VerifiedRequestIdentity} from "./types";

export class AuthenticationError extends Error {
  constructor(readonly category: "AUTHENTICATION" | "APP_CHECK") {
    super(category);
    this.name = "AuthenticationError";
  }
}

export interface RequestAuthenticator {
  verify(
    authorizationHeader: string | undefined,
    appCheckHeader: string | undefined,
    requireAppCheck: boolean,
  ): Promise<VerifiedRequestIdentity>;
}

export class FirebaseRequestAuthenticator implements RequestAuthenticator {
  async verify(
    authorizationHeader: string | undefined,
    appCheckHeader: string | undefined,
    requireAppCheck: boolean,
  ): Promise<VerifiedRequestIdentity> {
    const match = /^Bearer ([^\s]+)$/.exec(authorizationHeader ?? "");
    if (match === null || match[1].length > 8_192) {
      throw new AuthenticationError("AUTHENTICATION");
    }
    let uid: string;
    try {
      const decoded = await getAuth().verifyIdToken(match[1], true);
      if (typeof decoded.uid !== "string" || decoded.uid.length === 0) {
        throw new Error("invalid-uid");
      }
      uid = decoded.uid;
    } catch {
      throw new AuthenticationError("AUTHENTICATION");
    }

    if (!requireAppCheck) return {uid};
    if (appCheckHeader === undefined || appCheckHeader.length === 0 ||
        appCheckHeader.length > 8_192) {
      throw new AuthenticationError("APP_CHECK");
    }
    try {
      const decoded = await getAppCheck().verifyToken(appCheckHeader, {
        consume: true,
      });
      if (typeof decoded.appId !== "string" || decoded.appId.length === 0) {
        throw new Error("invalid-app-id");
      }
      if (decoded.alreadyConsumed === true) {
        throw new Error("replayed-app-check-token");
      }
      return {uid, appId: decoded.appId};
    } catch {
      throw new AuthenticationError("APP_CHECK");
    }
  }
}
