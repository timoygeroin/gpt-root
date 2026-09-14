import test from 'node:test';
import assert from 'node:assert/strict';
import manifest from '../contracts/canonical-runtime-cell.manifest.json' with { type: 'json' };

const SHA256 = /^[a-f0-9]{64}$/;

test('canonical runtime cell fails closed while current provenance is incomplete', () => {
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

test('manifest preserves the proven State 018 executable ancestor without promoting it to State 025 provenance', () => {
  const ancestor = manifest.proven_ancestor;

  assert.equal(ancestor.state_id, 'STATE-20260812-MONDAYID-HUMAN-FOCUS-018');
  assert.equal(ancestor.evidence_status, 'PROVEN_ANCESTOR');
  assert.equal(ancestor.continuity_to_current_state, 'NOT_PROVEN');
  assert.match(ancestor.archive_sha256, SHA256);
  assert.match(ancestor.genome_sha256, SHA256);
  assert.match(ancestor.ledger_head, SHA256);

  assert.equal(manifest.execution_policy.ancestor_bound_execution_allowed, true);
  assert.equal(manifest.execution_policy.forbid_ancestor_hash_as_current_hash, true);
  assert.equal(manifest.claims.proven_executable_ancestor_observed, true);
  assert.equal(manifest.claims.ancestor_to_current_continuity_proven, false);

  assert.notEqual(ancestor.genome_sha256, manifest.provenance.parent_genome_hash);
  assert.equal(manifest.provenance.parent_genome_hash, null);
});
