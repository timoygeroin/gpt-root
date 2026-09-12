import { createHash } from 'node:crypto';

const ROLES = ['discover', 'lineage', 'skeptic', 'reconcile'];
const EXECUTION_CONTRACT = Object.freeze({
  id: 'MONDAYID_VERTICAL_SLICE',
  version: 3,
  maxWorkers: 8,
  mutation: 'none',
  disagreementPolicy: 'preserve',
  missingEvidencePolicy: 'fail-closed',
  lineagePolicy: 'explicit-boundary',
  verificationPolicy: 'local-integrity-not-independent-readback',
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

export function verifyVerticalSliceReceipt(receipt) {
  if (!receipt || typeof receipt !== 'object' || typeof receipt.receipt_hash !== 'string') return false;
  const { receipt_hash: claimedHash, ...receiptBody } = receipt;
  return sha256(receiptBody) === claimedHash;
}

export function runVerticalSlice(input, options = {}) {
  const inputHash = sha256(input ?? null);
  const requestId = options.requestId ?? `req-${inputHash.slice(0, 12)}`;
  const parentStateHash = typeof options.parentStateHash === 'string' && options.parentStateHash.trim()
    ? options.parentStateHash.trim()
    : null;
  const lineageStatus = parentStateHash ? 'BOUND' : 'UNBOUND';
  const evidence = Array.isArray(input?.evidence) ? input.evidence : [];
  const requestedWorkerCount = Number.isInteger(options.workerCount) ? options.workerCount : ROLES.length;
  const workerCount = Math.min(Math.max(requestedWorkerCount, 0), EXECUTION_CONTRACT.maxWorkers);
  const workers = Array.from({ length: workerCount }, (_, index) => {
    const role = ROLES[index % ROLES.length];
    const roleInstance = Math.floor(index / ROLES.length) + 1;
    return {
      workerId: `${requestId}:w${index + 1}`,
      role,
      roleInstance,
      status: evidence.length ? 'COMPLETE' : 'BLOCKED_MISSING_EVIDENCE',
      evidenceIds: evidence.map((item) => item.id).filter(Boolean),
      hypothesis: evidence.length
        ? `${role}#${roleInstance}: processed ${evidence.length} evidence item(s)`
        : `${role}#${roleInstance}: no evidence available`,
    };
  });
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
    unknowns,
    mutation: 'none',
  };
  const receipt = { ...receiptBody, receipt_hash: sha256(receiptBody) };
  const receiptHashValid = verifyVerticalSliceReceipt(receipt);

  return {
    contract: EXECUTION_CONTRACT.id,
    contract_version: EXECUTION_CONTRACT.version,
    status: reducerDecision.startsWith('REJECT_') ? 'BLOCKED' : 'COMPLETE',
    workers,
    disagreement: contradictions,
    receipt,
    verification: {
      receipt_hash_valid: receiptHashValid,
      scope: 'LOCAL_INTEGRITY_ONLY',
      independent: false,
    },
  };
}
