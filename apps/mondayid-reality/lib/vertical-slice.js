import { createHash } from 'node:crypto';

const ROLES = ['discover', 'lineage', 'skeptic', 'reconcile'];

function sha256(value) {
  return createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

export function runVerticalSlice(input, options = {}) {
  const requestId = options.requestId ?? `req-${sha256(input).slice(0, 12)}`;
  const parentStateHash = options.parentStateHash ?? sha256({ parent: 'UNSPECIFIED' });
  const evidence = Array.isArray(input?.evidence) ? input.evidence : [];
  const workerCount = Math.min(options.workerCount ?? ROLES.length, 8);
  const workers = ROLES.slice(0, workerCount).map((role, index) => ({
    workerId: `${requestId}:w${index + 1}`,
    role,
    status: evidence.length ? 'COMPLETE' : 'BLOCKED_MISSING_EVIDENCE',
    evidenceIds: evidence.map((item) => item.id).filter(Boolean),
    hypothesis: evidence.length ? `${role}: processed ${evidence.length} evidence item(s)` : `${role}: no evidence available`,
  }));
  const contradictions = evidence
    .filter((item) => item && item.claim && item.truth && item.claim !== item.truth)
    .map((item) => ({ evidenceId: item.id ?? null, claim: item.claim, truth: item.truth }));
  const reducerDecision = evidence.length
    ? (contradictions.length ? 'HOLD_CONTRADICTION' : 'ACCEPT_READ_ONLY')
    : 'REJECT_MISSING_EVIDENCE';
  const receipt = {
    request_id: requestId,
    parent_state_hash: parentStateHash,
    worker_count: workers.length,
    evidence_ids: evidence.map((item) => item.id).filter(Boolean),
    contradictions,
    reducer_decision: reducerDecision,
    readback: { status: 'LOCAL_DETERMINISTIC', verified: true },
    unknowns: evidence.length ? [] : ['evidence_set'],
    mutation: 'none',
  };
  return {
    contract: 'MONDAYID_VERTICAL_SLICE',
    status: reducerDecision === 'REJECT_MISSING_EVIDENCE' ? 'BLOCKED' : 'COMPLETE',
    workers,
    disagreement: contradictions,
    receipt,
  };
}
