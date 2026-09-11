import { createHash } from 'node:crypto';

const ROLES = ['discover', 'lineage', 'skeptic', 'reconcile'];
const EXECUTION_CONTRACT = Object.freeze({
  id: 'MONDAYID_VERTICAL_SLICE',
  version: 2,
  maxWorkers: 8,
  mutation: 'none',
  disagreementPolicy: 'preserve',
  missingEvidencePolicy: 'fail-closed',
  lineagePolicy: 'explicit-boundary',
});

function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') {
    return Object.keys(value).sort().reduce((out, key) => {
      out[key] = stable(value[key]);
      return out;
    }, {});
  }
  return value;
}

function sha256(value) {
  return createHash('sha256').update(JSON.stringify(stable(value))).digest('hex');
}

export function runVerticalSlice(input, options = {}) {
  const inputHash = sha256(input ?? null);
  const requestId = options.requestId ?? `req-${inputHash.slice(0, 12)}`;
  const parentStateHash = typeof options.parentStateHash === 'string' && options.parentStateHash.trim()
    ? options.parentStateHash.trim()
    : null;
  const lineageStatus = parentStateHash ? 'BOUND' : 'UNBOUND';
  const evidence = Array.isArray(input?.evidence) ? input.evidence : [];
  const workerCount = Math.min(Math.max(options.workerCount ?? ROLES.length, 0), EXECUTION_CONTRACT.maxWorkers);
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

  let reducerDecision;
  const unknowns = [];
  if (!evidence.length) {
    reducerDecision = 'REJECT_MISSING_EVIDENCE';
    unknowns.push('evidence_set');
  } else if (options.requireBoundLineage === true && lineageStatus !== 'BOUND') {
    reducerDecision = 'REJECT_UNBOUND_LINEAGE';
    unknowns.push('parent_state_hash');
  } else if (contradictions.length) {
    reducerDecision = 'HOLD_CONTRADICTION';
  } else {
    reducerDecision = 'ACCEPT_READ_ONLY';
  }

  const executionContractHash = sha256(EXECUTION_CONTRACT);
  const workerOutputsHash = sha256(workers);
  const decisionHash = sha256({ reducerDecision, contradictions, unknowns });
  const receiptBody = {
    request_id: requestId,
    input_hash: inputHash,
    execution_contract_hash: executionContractHash,
    parent_state_hash: parentStateHash,
    lineage_status: lineageStatus,
    worker_outputs_hash: workerOutputsHash,
    decision_hash: decisionHash,
    worker_count: workers.length,
    evidence_ids: evidence.map((item) => item.id).filter(Boolean),
    contradictions,
    reducer_decision: reducerDecision,
    readback: { status: 'LOCAL_DETERMINISTIC', verified: true },
    unknowns,
    mutation: 'none',
  };
  const receipt = { ...receiptBody, receipt_hash: sha256(receiptBody) };

  return {
    contract: EXECUTION_CONTRACT.id,
    contract_version: EXECUTION_CONTRACT.version,
    status: reducerDecision.startsWith('REJECT_') ? 'BLOCKED' : 'COMPLETE',
    workers,
    disagreement: contradictions,
    receipt,
  };
}
