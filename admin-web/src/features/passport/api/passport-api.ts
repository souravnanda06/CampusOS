import { apiClient } from '@/services/api/api-client';

export interface InstitutionPublicKey {
  issuer: string;
  issuerKeyId: string;
  publicKey: string;
  algorithm: string;
}

export interface TrustBundleIdentity {
  certificateId: string;
  issuerKeyId: string;
  keyId: string;
  publicKey: string;
  status: string;
  userId: string;
  userName?: string;
  validFrom: string;
  validTo: string;
}

export interface TrustBundlePayload {
  version: number;
  generatedAt: number;
  expiresAt: number;
  issuerKeyId: string;
  institution?: {
    keyId: string;
    publicKey: string;
  };
  identities: TrustBundleIdentity[];
  revokedKeyIds: string[];
}

export interface TrustBundle {
  payload: TrustBundlePayload;
  signature: string;
}

export interface StudentPassportKey {
  keyId: string;
  userId: string;
  publicKey: string;
  keyType: string;
  status: string;
  certificate?: {
    id: string;
    serialNumber?: string;
    status: string;
    validFrom: string;
    validTo: string;
    issuerKeyId: string;
    signature: string;
  } | null;
  certificateStatus?: string | null;
  validFrom?: string | null;
  validTo?: string | null;
}

export interface CertificateVerificationResult {
  valid: boolean;
  reason?: string;
  details?: Record<string, unknown>;
  certificate?: Record<string, unknown>;
}

export interface PresentationVerificationResult {
  valid: boolean;
  reason?: string;
  userId?: string;
  keyId?: string;
  certificateId?: string;
  expiresAt?: number;
  user?: {
    name: string;
    branch?: string;
    year?: string | number;
    course?: string;
    registrationNumber?: string;
  };
}

export const passportApi = {
  getInstitutionalPublicKey: async (): Promise<InstitutionPublicKey> => {
    return apiClient.get<InstitutionPublicKey>('/passport/institution/public-key');
  },

  getTrustBundle: async (ttlSeconds = 86400): Promise<TrustBundle> => {
    return apiClient.get<TrustBundle>(`/passport/trust-bundle?ttlSeconds=${ttlSeconds}`);
  },

  getStudentKey: async (studentId: string): Promise<StudentPassportKey> => {
    return apiClient.get<StudentPassportKey>(`/passport/keys/${studentId}`);
  },

  revokeKey: async (keyId: string): Promise<{ message: string; key: unknown }> => {
    return apiClient.post<{ message: string; key: unknown }>(`/passport/keys/${keyId}/revoke`);
  },

  verifyCertificate: async (payload: { certificateId?: string; certificate?: unknown }): Promise<CertificateVerificationResult> => {
    return apiClient.post<CertificateVerificationResult>('/passport/verify-certificate', payload);
  },

  verifyPresentation: async (payload: {
    payload: Record<string, unknown>;
    signature: string;
  }): Promise<PresentationVerificationResult> => {
    return apiClient.post<PresentationVerificationResult>('/passport/verify', payload);
  },
};
