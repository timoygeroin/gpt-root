import test from 'node:test';
import assert from 'node:assert/strict';
import { runVerticalSlice } from '../lib/vertical-slice.js';

test('vertical slice completes deterministically with evidence', () => {
  const input = { evidence: [{ id: 'E1', claim: 'reported', truth: 'reported' }] };
  const a = runVerticalSlice(input, { requestId: 'fixed', parentStateHash: 'PARENT' });
  const b = runVerticalSlice(input, { requestId: 'fixed', parentStateHash: 'PARENT' });
  assert.deepEqual(a, b);
  assert.equal(a.status, 'COMPLETE');
  assert.equal(a.receipt.reducer_decision, 'ACCEPT_READ_ONLY');
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
