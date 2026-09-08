import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const contractPath = path.join(here, '..', 'contracts', 'vertical-slice.contract.json');
const contract = JSON.parse(fs.readFileSync(contractPath, 'utf8'));

test('vertical slice contract is fail-closed and receipt-bearing', () => {
  assert.equal(contract.contract, 'MONDAYID_VERTICAL_SLICE');
  assert.equal(contract.scope.mutation, 'none');
  assert.ok(contract.scope.workers.materialized_max > 0);
  assert.ok(contract.required_steps.includes('preserve_disagreement'));
  assert.ok(contract.required_steps.includes('emit_receipt'));
  for (const field of ['request_id', 'parent_state_hash', 'worker_count', 'evidence_ids', 'contradictions', 'reducer_decision', 'readback', 'unknowns']) {
    assert.ok(contract.receipt_requirements.includes(field), `missing receipt field: ${field}`);
  }
  assert.equal(contract.acceptance.must_fail_closed_on_missing_evidence, true);
  assert.equal(contract.acceptance.must_not_hide_worker_disagreement, true);
});
