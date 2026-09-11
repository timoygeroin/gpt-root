import test from 'node:test';
import assert from 'node:assert/strict';
import { runVerticalSlice } from '../lib/vertical-slice.js';

test('vertical slice completes deterministically with evidence and bound lineage', () => {
  const input = { evidence: [{ id: 'E1', claim: 'reported', truth: 'reported' }] };
  const a = runVerticalSlice(input, { requestId: 'fixed', parentStateHash: 'PARENT' });
  const b = runVerticalSlice(input, { requestId: 'fixed', parentStateHash: 'PARENT' });
  assert.deepEqual(a, b);
  assert.equal(a.status, 'COMPLETE');
  assert.equal(a.receipt.reducer_decision, 'ACCEPT_READ_ONLY');
  assert.equal(a.receipt.lineage_status, 'BOUND');
  assert.equal(a.receipt.parent_state_hash, 'PARENT');
  assert.match(a.receipt.input_hash, /^[a-f0-9]{64}$/);
  assert.match(a.receipt.execution_contract_hash, /^[a-f0-9]{64}$/);
  assert.match(a.receipt.worker_outputs_hash, /^[a-f0-9]{64}$/);
  assert.match(a.receipt.decision_hash, /^[a-f0-9]{64}$/);
  assert.match(a.receipt.receipt_hash, /^[a-f0-9]{64}$/);
  assert.equal(a.receipt.readback.verified, true);
  assert.equal(a.receipt.mutation, 'none');
});

test('vertical slice fails closed without evidence and preserves the blocker', () => {
  const result = runVerticalSlice({ evidence: [] }, { requestId: 'empty', parentStateHash: 'PARENT' });
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.receipt.reducer_decision, 'REJECT_MISSING_EVIDENCE');
  assert.deepEqual(result.receipt.unknowns, ['evidence_set']);
  assert.ok(result.workers.every((worker) => worker.status === 'BLOCKED_MISSING_EVIDENCE'));
});

test('vertical slice retains contradiction instead of voting it away', () => {
  const result = runVerticalSlice({ evidence: [{ id: 'E2', claim: 'reported', truth: 'official' }] }, { requestId: 'contradiction', parentStateHash: 'PARENT' });
  assert.equal(result.receipt.reducer_decision, 'HOLD_CONTRADICTION');
  assert.equal(result.disagreement.length, 1);
  assert.equal(result.receipt.contradictions[0].evidenceId, 'E2');
});

test('unbound lineage stays explicit instead of masquerading as a hash', () => {
  const result = runVerticalSlice({ evidence: [{ id: 'E3', claim: 'x', truth: 'x' }] }, { requestId: 'unbound' });
  assert.equal(result.receipt.lineage_status, 'UNBOUND');
  assert.equal(result.receipt.parent_state_hash, null);
  assert.equal(result.receipt.reducer_decision, 'ACCEPT_READ_ONLY');
});

test('production-like invocation fails closed when lineage is required but unbound', () => {
  const result = runVerticalSlice(
    { evidence: [{ id: 'E4', claim: 'x', truth: 'x' }] },
    { requestId: 'strict-unbound', requireBoundLineage: true },
  );
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.receipt.reducer_decision, 'REJECT_UNBOUND_LINEAGE');
  assert.deepEqual(result.receipt.unknowns, ['parent_state_hash']);
});
