import * as React from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  passportApi,
  type TrustBundleIdentity,
  type CertificateVerificationResult,
  type PresentationVerificationResult,
} from './api/passport-api';
import { PageHeader } from '@/components/ui/page-header';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { ConfirmDialog } from '@/components/feedback/confirm-dialog';
import { useToast } from '@/components/ui/toast';
import { formatDate } from '@/lib/utils';
import {
  KeyRound,
  ShieldCheck,
  Download,
  Copy,
  Check,
  RefreshCw,
  AlertTriangle,
  CheckCircle2,
  FileCheck,
  Layers,
  Lock,
  QrCode,
} from 'lucide-react';

export const PassportPage: React.FC = () => {
  const queryClient = useQueryClient();
  const { addToast } = useToast();

  const [copiedKey, setCopiedKey] = React.useState(false);
  const [certIdInput, setCertIdInput] = React.useState('');
  const [verifying, setVerifying] = React.useState(false);
  const [verifyResult, setVerifyResult] = React.useState<CertificateVerificationResult | null>(null);

  const [presentationJson, setPresentationJson] = React.useState('');
  const [verifyingPres, setVerifyingPres] = React.useState(false);
  const [presResult, setPresResult] = React.useState<PresentationVerificationResult | null>(null);

  const [keyToRevoke, setKeyToRevoke] = React.useState<{
    keyId: string;
    userId: string;
    userName?: string;
  } | null>(null);

  const {
    data: caKey,
    isLoading: caLoading,
    error: caError,
  } = useQuery({
    queryKey: ['passport-ca-key'],
    queryFn: () => passportApi.getInstitutionalPublicKey(),
  });

  const {
    data: trustBundle,
    isLoading: bundleLoading,
    error: bundleError,
    refetch: refetchBundle,
  } = useQuery({
    queryKey: ['passport-trust-bundle'],
    queryFn: () => passportApi.getTrustBundle(86400),
  });

  const revokeMutation = useMutation({
    mutationFn: (keyId: string) => passportApi.revokeKey(keyId),
    onSuccess: () => {
      addToast({
        type: 'success',
        title: 'Key Revoked',
        message: 'The device identity key and all its certificates have been revoked.',
      });
      queryClient.invalidateQueries({ queryKey: ['passport-trust-bundle'] });
      setKeyToRevoke(null);
    },
    onError: (err: unknown) => {
      addToast({
        type: 'error',
        title: 'Revocation Failed',
        message: err instanceof Error ? err.message : 'Failed to revoke device key',
      });
    },
  });

  const handleCopy = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(true);
    addToast({
      type: 'info',
      title: 'Copied to Clipboard',
      message: 'Institutional public key copied.',
    });
    setTimeout(() => setCopiedKey(false), 2000);
  };

  const handleDownloadBundle = () => {
    if (!trustBundle) return;
    const blob = new Blob([JSON.stringify(trustBundle, null, 2)], {
      type: 'application/json',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `campusos-trust-bundle-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    addToast({
      type: 'success',
      title: 'Trust Bundle Exported',
      message: 'Signed institutional trust bundle downloaded for offline gate verification.',
    });
  };

  const handleVerifyCert = async (e: React.FormEvent) => {
    e.preventDefault();
    const raw = certIdInput.trim();
    if (!raw) return;

    setVerifying(true);
    setVerifyResult(null);
    try {
      let res: CertificateVerificationResult;
      if (raw.startsWith('{')) {
        res = await passportApi.verifyCertificate({ certificate: JSON.parse(raw) });
      } else {
        res = await passportApi.verifyCertificate({ certificateId: raw });
      }
      setVerifyResult(res);
    } catch (err: unknown) {
      setVerifyResult({
        valid: false,
        reason: err instanceof Error ? err.message : 'Verification request failed',
      });
    } finally {
      setVerifying(false);
    }
  };

  const handleVerifyPresentation = async (e: React.FormEvent) => {
    e.preventDefault();
    const raw = presentationJson.trim();
    if (!raw) return;

    setVerifyingPres(true);
    setPresResult(null);
    try {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const payload = (parsed.payload || parsed.p || parsed) as Record<string, unknown>;
      const signature = String(parsed.signature || parsed.s || '');
      const res = await passportApi.verifyPresentation({ payload, signature });
      setPresResult(res);
    } catch (err: unknown) {
      setPresResult({
        valid: false,
        reason: err instanceof Error ? err.message : 'Invalid presentation JSON or signature',
      });
    } finally {
      setVerifyingPres(false);
    }
  };

  const identities = trustBundle?.payload?.identities || [];
  const revokedKeyIds = trustBundle?.payload?.revokedKeyIds || [];
  const expiresIso = trustBundle?.payload?.expiresAt
    ? new Date(trustBundle.payload.expiresAt * 1000).toISOString()
    : null;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Passport Cryptographic Trust Mesh"
        subtitle="Institutional Ed25519 Certificate Authority (CA), device binding registry, presentation verifier, and offline trust bundles."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => refetchBundle()}
              className="gap-1.5"
            >
              <RefreshCw className="h-4 w-4" />
              <span>Refresh Trust Bundle</span>
            </Button>
            <Button
              size="sm"
              onClick={handleDownloadBundle}
              disabled={!trustBundle}
              className="gap-1.5"
            >
              <Download className="h-4 w-4" />
              <span>Export Trust Bundle</span>
            </Button>
          </div>
        }
      />

      {/* Top 2 Cards: CA Anchor & Bundle Info */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="rounded-lg border border-border bg-card p-5 shadow-xs space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-primary">
              <ShieldCheck className="h-5 w-5" />
              <h3 className="font-semibold text-sm">Institutional Root Authority</h3>
            </div>
            <Badge variant="default" className="text-[10px] uppercase font-mono">
              Root Anchor
            </Badge>
          </div>

          {caLoading ? (
            <Skeleton className="h-28 w-full" />
          ) : caError ? (
            <div className="rounded-md bg-destructive/10 p-3 text-xs text-destructive">
              Failed to load institutional key material.
            </div>
          ) : caKey ? (
            <div className="space-y-3 text-xs">
              <div className="grid grid-cols-2 gap-2 text-muted-foreground">
                <div>
                  <span className="font-medium text-foreground">Issuer:</span> {caKey.issuer}
                </div>
                <div>
                  <span className="font-medium text-foreground">Algorithm:</span> {caKey.algorithm}
                </div>
              </div>

              <div>
                <span className="font-medium text-foreground block mb-1">
                  Key Identifier (KID):
                </span>
                <code className="block rounded bg-muted/60 p-2 font-mono text-[11px] select-all break-all border border-border/50">
                  {caKey.issuerKeyId}
                </code>
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <span className="font-medium text-foreground">
                    Public Key (Base64):
                  </span>
                  <button
                    type="button"
                    onClick={() => handleCopy(caKey.publicKey)}
                    className="flex items-center gap-1 text-[11px] text-primary hover:underline"
                  >
                    {copiedKey ? <Check className="h-3 w-3" /> : <Copy className="h-3 w-3" />}
                    <span>{copiedKey ? 'Copied' : 'Copy'}</span>
                  </button>
                </div>
                <code className="block rounded bg-muted/60 p-2 font-mono text-[11px] select-all break-all border border-border/50">
                  {caKey.publicKey}
                </code>
              </div>
            </div>
          ) : null}
        </div>

        {/* Trust Bundle Summary Card */}
        <div className="rounded-lg border border-border bg-card p-5 shadow-xs space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-primary">
              <Layers className="h-5 w-5" />
              <h3 className="font-semibold text-sm">Active Trust Bundle Status</h3>
            </div>
            <Badge variant="secondary" className="text-[10px] uppercase font-mono">
              Offline Verifiers
            </Badge>
          </div>

          {bundleLoading ? (
            <Skeleton className="h-28 w-full" />
          ) : bundleError ? (
            <div className="rounded-md bg-destructive/10 p-3 text-xs text-destructive">
              Failed to load trust bundle.
            </div>
          ) : trustBundle ? (
            <div className="space-y-3 text-xs">
              <div className="grid grid-cols-3 gap-3">
                <div className="rounded border border-border/60 p-2.5 bg-muted/20">
                  <div className="text-[11px] text-muted-foreground">Certified Devices</div>
                  <div className="text-xl font-bold font-mono mt-0.5">
                    {identities.length}
                  </div>
                </div>

                <div className="rounded border border-border/60 p-2.5 bg-muted/20">
                  <div className="text-[11px] text-muted-foreground">Revoked Keys</div>
                  <div className="text-xl font-bold font-mono text-rose-600 dark:text-rose-400 mt-0.5">
                    {revokedKeyIds.length}
                  </div>
                </div>

                <div className="rounded border border-border/60 p-2.5 bg-muted/20">
                  <div className="text-[11px] text-muted-foreground">Bundle Valid Until</div>
                  <div className="text-[11px] font-semibold mt-1">
                    {formatDate(expiresIso)}
                  </div>
                </div>
              </div>

              <div>
                <span className="font-medium text-foreground block mb-1">
                  Root Cryptographic Signature:
                </span>
                <code className="block rounded bg-muted/60 p-2 font-mono text-[11px] select-all break-all border border-border/50 text-muted-foreground">
                  {trustBundle.signature}
                </code>
              </div>

              <div className="flex items-center gap-1.5 text-[11px] text-emerald-600 dark:text-emerald-400">
                <CheckCircle2 className="h-3.5 w-3.5" />
                <span>Signed by CampusOS Ed25519 Root Authority (v{trustBundle.payload?.version || 1})</span>
              </div>
            </div>
          ) : null}
        </div>
      </div>

      {/* Diagnostic Verifiers Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* 10-Rule Certificate Verification Utility */}
        <div className="rounded-lg border border-border bg-card p-5 shadow-xs space-y-4">
          <div className="flex items-center gap-2 text-primary">
            <FileCheck className="h-5 w-5" />
            <h3 className="font-semibold text-sm">10-Rule Certificate Verifier Diagnostic</h3>
          </div>
          <p className="text-xs text-muted-foreground">
            Audit any device certificate ID (UUID) or full JSON payload against the 10 institutional verification rules.
          </p>

          <form onSubmit={handleVerifyCert} className="flex gap-2">
            <Input
              placeholder="Certificate UUID or JSON payload..."
              value={certIdInput}
              onChange={(e) => setCertIdInput(e.target.value)}
              className="text-xs font-mono"
            />
            <Button type="submit" disabled={verifying || !certIdInput.trim()} className="shrink-0 gap-1.5">
              <KeyRound className="h-4 w-4" />
              <span>{verifying ? 'Verifying...' : 'Verify Cert'}</span>
            </Button>
          </form>

          {verifyResult && (
            <div
              className={`rounded-md border p-4 text-xs space-y-2 ${
                verifyResult.valid
                  ? 'border-emerald-500/40 bg-emerald-500/10 text-emerald-950 dark:text-emerald-200'
                  : 'border-destructive/40 bg-destructive/10 text-destructive'
              }`}
            >
              <div className="flex items-center gap-2 font-semibold">
                {verifyResult.valid ? (
                  <>
                    <CheckCircle2 className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                    <span>Certificate is Cryptographically Valid &amp; Active</span>
                  </>
                ) : (
                  <>
                    <AlertTriangle className="h-4 w-4 text-destructive" />
                    <span>Certificate Verification Failed</span>
                  </>
                )}
              </div>
              {verifyResult.reason && (
                <p className="text-[11px] font-mono">Reason: {verifyResult.reason}</p>
              )}
              {verifyResult.details && (
                <pre className="mt-2 rounded bg-black/5 dark:bg-black/40 p-2 font-mono text-[10px] overflow-x-auto">
                  {JSON.stringify(verifyResult.details, null, 2)}
                </pre>
              )}
            </div>
          )}
        </div>

        {/* Live Passport Presentation Verifier (mirrors Flutter PassportVerifierScreen) */}
        <div className="rounded-lg border border-border bg-card p-5 shadow-xs space-y-4">
          <div className="flex items-center gap-2 text-primary">
            <QrCode className="h-5 w-5" />
            <h3 className="font-semibold text-sm">Passport Presentation Verifier</h3>
          </div>
          <p className="text-xs text-muted-foreground">
            Verify a student&apos;s rotating Ed25519 QR/BLE Passport presentation envelope (`&#123; payload, signature &#125;` or compact `&#123; p, s &#125;`).
          </p>

          <form onSubmit={handleVerifyPresentation} className="space-y-2">
            <textarea
              rows={3}
              placeholder='{"payload": {...}, "signature": "..."}'
              value={presentationJson}
              onChange={(e) => setPresentationJson(e.target.value)}
              className="w-full rounded-lg border border-input bg-background p-2.5 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-ring"
            />
            <Button
              type="submit"
              size="sm"
              disabled={verifyingPres || !presentationJson.trim()}
              className="gap-1.5"
            >
              <QrCode className="h-3.5 w-3.5" />
              <span>{verifyingPres ? 'Verifying...' : 'Verify Presentation'}</span>
            </Button>
          </form>

          {presResult && (
            <div
              className={`rounded-md border p-4 text-xs space-y-1.5 ${
                presResult.valid
                  ? 'border-emerald-500/40 bg-emerald-500/10 text-emerald-950 dark:text-emerald-200'
                  : 'border-destructive/40 bg-destructive/10 text-destructive'
              }`}
            >
              <div className="flex items-center gap-2 font-semibold">
                {presResult.valid ? (
                  <>
                    <CheckCircle2 className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                    <span>Passport Presentation Authentic</span>
                  </>
                ) : (
                  <>
                    <AlertTriangle className="h-4 w-4 text-destructive" />
                    <span>Presentation Rejected ({presResult.reason})</span>
                  </>
                )}
              </div>
              {presResult.user && (
                <p className="text-[11px]">
                  Identity: <strong>{presResult.user.name}</strong> ({presResult.user.registrationNumber || presResult.userId}) • {presResult.user.branch} Yr {presResult.user.year}
                </p>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Certified Devices Registry Table */}
      <div className="rounded-lg border border-border bg-card shadow-xs overflow-hidden">
        <div className="p-4 border-b border-border flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Lock className="h-4 w-4 text-primary" />
            <h3 className="font-semibold text-sm">
              Certified Device Public Key Registry ({identities.length})
            </h3>
          </div>
          <span className="text-xs text-muted-foreground font-mono">
            Synced from trust bundle
          </span>
        </div>

        {bundleLoading ? (
          <div className="p-6 space-y-3">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : identities.length === 0 ? (
          <div className="p-8 text-center text-xs text-muted-foreground">
            No student devices currently enrolled in the institutional trust bundle.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-border bg-muted/40 text-muted-foreground uppercase text-[10px] font-mono tracking-wider">
                  <th className="py-2.5 px-4 font-semibold">Certificate ID</th>
                  <th className="py-2.5 px-4 font-semibold">Student / Key ID</th>
                  <th className="py-2.5 px-4 font-semibold">Public Key</th>
                  <th className="py-2.5 px-4 font-semibold">Valid Period</th>
                  <th className="py-2.5 px-4 font-semibold">Status</th>
                  <th className="py-2.5 px-4 font-semibold text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/60">
                {identities.map((cert: TrustBundleIdentity) => (
                  <tr key={cert.certificateId} className="hover:bg-muted/30 transition-colors">
                    <td className="py-3 px-4 font-mono font-medium text-foreground">
                      <button
                        type="button"
                        onClick={() => setCertIdInput(cert.certificateId)}
                        className="hover:text-primary hover:underline"
                        title="Load into Certificate Verifier"
                      >
                        {cert.certificateId.substring(0, 10)}...
                      </button>
                    </td>
                    <td className="py-3 px-4">
                      <p className="font-medium text-foreground">{cert.userName || cert.userId.substring(0, 12)}</p>
                      <p className="font-mono text-[10px] text-muted-foreground">
                        Key: {cert.keyId.substring(0, 10)}...
                      </p>
                    </td>
                    <td className="py-3 px-4 font-mono text-muted-foreground max-w-[160px] truncate" title={cert.publicKey}>
                      {cert.publicKey}
                    </td>
                    <td className="py-3 px-4 text-muted-foreground">
                      {formatDate(cert.validFrom)} - {formatDate(cert.validTo)}
                    </td>
                    <td className="py-3 px-4">
                      <Badge
                        variant={cert.status === 'ACTIVE' ? 'default' : 'destructive'}
                        className="text-[10px] uppercase font-mono px-1.5 py-0"
                      >
                        {cert.status}
                      </Badge>
                    </td>
                    <td className="py-3 px-4 text-right">
                      {cert.status === 'ACTIVE' && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() =>
                            setKeyToRevoke({
                              keyId: cert.keyId,
                              userId: cert.userId,
                              userName: cert.userName,
                            })
                          }
                          className="h-7 text-xs text-destructive hover:bg-destructive/10"
                        >
                          Revoke Key
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Revocation Confirmation Dialog */}
      <ConfirmDialog
        open={!!keyToRevoke}
        onOpenChange={(open) => !open && setKeyToRevoke(null)}
        title="Revoke Device Identity Key"
        description={`Are you sure you want to revoke the identity key for ${keyToRevoke?.userName || keyToRevoke?.userId}? All associated institutional certificates will be permanently invalidated and the user must re-enroll their device.`}
        confirmLabel="Revoke Key"
        variant="destructive"
        onConfirm={() => {
          if (keyToRevoke) revokeMutation.mutate(keyToRevoke.keyId);
        }}
        isLoading={revokeMutation.isPending}
      />
    </div>
  );
};
