const CORE = 'https://mondayid-reality.vercel.app/observe';
const TZOFAR_PROBE = 'https://mondayid-tzofar-probe.vercel.app/';

async function readJSON(url, timeoutMs = 3500) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { cache: 'no-store', signal: controller.signal, headers: { 'user-agent': 'MONDAYID-REALITY-WEB/1.0' } });
    const text = await response.text();
    let body = null;
    try { body = JSON.parse(text); } catch {}
    return { ok: response.ok, status: response.status, body };
  } catch (error) {
    return { ok: false, status: null, body: null, error: error?.name || 'FETCH_FAILED' };
  } finally {
    clearTimeout(timer);
  }
}

export default async function handler(_req, res) {
  const observedAt = new Date().toISOString();
  const [core, tzofar] = await Promise.all([readJSON(CORE), readJSON(TZOFAR_PROBE)]);
  const coreBody = core.body || {};
  const coreReceptors = Array.isArray(coreBody.receptors) ? coreBody.receptors : [];

  const receptors = coreReceptors.map(r => ({
    id: r.id,
    label: r.label,
    transport: r.transport,
    source: r.source,
    authority: r.authority,
    freshness: r.freshness,
    contract: r.contract,
    httpStatus: r.httpStatus ?? null
  }));

  receptors.push({
    id: 'tzofar-independent',
    label: 'Tzofar independent realtime probe',
    transport: tzofar.ok && tzofar.body?.state === 'SOCKET_OPEN' ? 'SOCKET_OPEN' : 'OFFLINE',
    source: 'SECONDARY',
    authority: 'SECONDARY',
    contract: 'INDEPENDENT_WEBSOCKET_PROBE',
    httpStatus: tzofar.status
  });

  res.setHeader('content-type', 'application/json; charset=utf-8');
  res.setHeader('cache-control', 'no-store');
  res.status(200).json({
    product: 'MONDAYID REALITY',
    mode: 'WEB_COGNITION_SURFACE',
    observedAt,
    surface: {
      authority: 'NONE',
      personalization: 'DEVICE_LOCAL_ONLY',
      sendsPersonalContextsToCloud: false
    },
    receptors,
    invariant: 'This web surface does not infer a personal physical condition from missing or secondary data.'
  });
}
