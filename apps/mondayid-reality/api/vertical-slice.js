import { runVerticalSlice } from '../lib/vertical-slice.js';

const MAX_BODY_BYTES = 64 * 1024;

function sendJson(res, statusCode, payload) {
  res.statusCode = statusCode;
  res.setHeader('content-type', 'application/json; charset=utf-8');
  res.setHeader('cache-control', 'no-store');
  return res.end(JSON.stringify(payload));
}

function normalizeBody(req) {
  if (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body)) return req.body;
  if (typeof req.body === 'string') return JSON.parse(req.body);
  return null;
}

export function executeVerticalSliceRequest(body) {
  if (!body || typeof body !== 'object') {
    return { statusCode: 400, payload: { ok: false, error: 'INVALID_BODY', mutation: 'none' } };
  }

  const input = body.input && typeof body.input === 'object' ? body.input : body;
  const options = body.options && typeof body.options === 'object' ? body.options : {};
  const result = runVerticalSlice(input, {
    requestId: typeof options.requestId === 'string' ? options.requestId : undefined,
    parentStateHash: typeof options.parentStateHash === 'string' ? options.parentStateHash : undefined,
    workerCount: Number.isInteger(options.workerCount) ? options.workerCount : undefined,
    requireBoundLineage: options.requireBoundLineage === true,
  });

  return {
    statusCode: 200,
    payload: {
      ok: true,
      mode: 'READ_ONLY_VERTICAL_SLICE',
      mutation: 'none',
      result,
      readback: {
        request_id: result.receipt.request_id,
        reducer_decision: result.receipt.reducer_decision,
        worker_count: result.receipt.worker_count,
        lineage_status: result.receipt.lineage_status,
        parent_state_hash: result.receipt.parent_state_hash,
        input_hash: result.receipt.input_hash,
        decision_hash: result.receipt.decision_hash,
        receipt_hash: result.receipt.receipt_hash,
        receipt_hash_valid: result.verification.receipt_hash_valid,
        verification_scope: result.verification.scope,
        independent_verification: result.verification.independent,
      },
    },
  };
}

export default async function handler(req, res) {
  if (req.method === 'GET') {
    return sendJson(res, 200, {
      ok: true,
      service: 'MONDAYID_VERTICAL_SLICE',
      mode: 'READ_ONLY',
      mutation: 'none',
      contract: 'input -> bounded workers -> contradiction reducer -> provenance receipt -> local integrity verification',
      verification_scope: 'LOCAL_INTEGRITY_ONLY',
      independent_verification: false,
    });
  }

  if (req.method !== 'POST') {
    res.setHeader('allow', 'GET, POST');
    return sendJson(res, 405, { ok: false, error: 'METHOD_NOT_ALLOWED', mutation: 'none' });
  }

  const declaredLength = Number(req.headers?.['content-length'] ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    return sendJson(res, 413, { ok: false, error: 'BODY_TOO_LARGE', mutation: 'none' });
  }

  try {
    const body = normalizeBody(req);
    if (!body) return sendJson(res, 400, { ok: false, error: 'INVALID_BODY', mutation: 'none' });
    const { statusCode, payload } = executeVerticalSliceRequest(body);
    return sendJson(res, statusCode, payload);
  } catch (error) {
    return sendJson(res, 400, {
      ok: false,
      error: 'INVALID_JSON',
      detail: error instanceof Error ? error.message : String(error),
      mutation: 'none',
    });
  }
}
