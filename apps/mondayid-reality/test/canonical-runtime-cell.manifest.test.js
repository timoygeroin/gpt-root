import test from 'node:test';
import assert from 'node:assert/strict';
import manifest from '../contracts/canonical-runtime-cell.manifest.json' with { type: 'json' };

test('canonical runtime cell fails closed while provenance is incomplete', () => {
  assert.equal(manifest.provenance.status, 'INCOMPLETE');
  assert.equal(manifest.execution_policy.canonical_execution_allowed, false);
  assert.equal(manifest.execution_policy.fail_closed, true);
  assert.equal(manifest.claims.registry_head_observed, true);
  assert.equal(manifest.claims.canonical_runtime_cell_proven, false);

  for (const field of manifest.execution_policy.required_before_canonical_execution) {
    assert.equal(manifest.provenance[field], null);
    assert.ok(manifest.provenance.missing.includes(field));
  }
});
