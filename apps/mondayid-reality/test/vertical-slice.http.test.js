import test from 'node:test';
import assert from 'node:assert/strict';
import handler, { executeVerticalSliceRequest } from '../api/vertical-slice.js';

function mockResponse() {
  const headers = {};
  return {
    statusCode: 200,
    headers,
    body: '',
    setHeader(name, value) { headers[name.toLowerCase()] = value; },
    end(value = '') { this.body = value; return value; },
  };
}

test('executeVerticalSliceRequest returns deterministic read-only receipt readback', () => {
  const body = {
    input: {
      evidence: [
        { id: 'ev-1', claim: 'A', truth: 'A' },
        { id: 'ev-2', claim: 'B', truth: 'B' },
      ],
    },
    options: { requestId: 'req-http-001', workerCount: 4 },
  };

  const first = executeVerticalSliceRequest(body);
  const second = executeVerticalSliceRequest(body);

  assert.equal(first.statusCode, 200);
  assert.deepEqual(first, second);
  assert.equal(first.payload.ok, true);
  assert.equal(first.payload.mutation, 'none');
  assert.equal(first.payload.readback.request_id, 'req-http-001');
  assert.equal(first.payload.readback.reducer_decision, 'ACCEPT_READ_ONLY');
  assert.equal(first.payload.readback.worker_count, 4);
  assert.equal(first.payload.readback.receipt_hash_valid, true);
  assert.equal(first.payload.readback.verification_scope, 'LOCAL_INTEGRITY_ONLY');
  assert.equal(first.payload.readback.independent_verification, false);
});

test('HTTP path exposes all eight materialized workers when requested', () => {
  const response = executeVerticalSliceRequest({
    input: { evidence: [{ id: 'ev-8', claim: 'A', truth: 'A' }] },
    options: { requestId: 'req-http-008', workerCount: 8 },
  });
  assert.equal(response.payload.result.workers.length, 8);
  assert.equal(response.payload.readback.worker_count, 8);
});

test('HTTP handler preserves contradiction and exposes receipt through readback', async () => {
  const req = {
    method: 'POST',
    headers: { 'content-length': '128' },
    body: {
      input: { evidence: [{ id: 'ev-conflict', claim: 'SAFE', truth: 'UNKNOWN' }] },
      options: { requestId: 'req-http-conflict' },
    },
  };
  const res = mockResponse();

  await handler(req, res);
  const payload = JSON.parse(res.body);

  assert.equal(res.statusCode, 200);
  assert.equal(payload.result.receipt.reducer_decision, 'HOLD_CONTRADICTION');
  assert.equal(payload.result.disagreement.length, 1);
  assert.equal(payload.readback.reducer_decision, 'HOLD_CONTRADICTION');
  assert.equal(payload.readback.receipt_hash_valid, true);
  assert.equal(payload.readback.independent_verification, false);
  assert.equal(payload.mutation, 'none');
});

test('HTTP handler is fail-closed when evidence is absent', async () => {
  const req = { method: 'POST', headers: {}, body: { input: {} } };
  const res = mockResponse();

  await handler(req, res);
  const payload = JSON.parse(res.body);

  assert.equal(res.statusCode, 200);
  assert.equal(payload.result.status, 'BLOCKED');
  assert.equal(payload.result.receipt.reducer_decision, 'REJECT_MISSING_EVIDENCE');
  assert.deepEqual(payload.result.receipt.unknowns, ['evidence_set']);
});

test('GET is a non-mutating capability readback with honest verification scope', async () => {
  const req = { method: 'GET', headers: {} };
  const res = mockResponse();

  await handler(req, res);
  const payload = JSON.parse(res.body);

  assert.equal(res.statusCode, 200);
  assert.equal(payload.service, 'MONDAYID_VERTICAL_SLICE');
  assert.equal(payload.mode, 'READ_ONLY');
  assert.equal(payload.mutation, 'none');
  assert.equal(payload.verification_scope, 'LOCAL_INTEGRITY_ONLY');
  assert.equal(payload.independent_verification, false);
});
