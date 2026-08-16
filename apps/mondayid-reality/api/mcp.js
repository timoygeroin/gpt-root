import { readFileSync } from "node:fs";
import { join } from "node:path";
import { randomUUID, createHmac, timingSafeEqual } from "node:crypto";
import {
  registerAppResource,
  registerAppTool,
  RESOURCE_MIME_TYPE,
} from "@modelcontextprotocol/ext-apps/server";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";

const VERSION = "0.3.1";
const WIDGET_URI = "ui://mondayid/reality-v3.html";
const SECRET = process.env.REALITY_STATE_SECRET || "mondayid-reality-demo-v3-not-for-live-safety";
const widgetHtml = readFileSync(join(process.cwd(), "public", "reality-widget.html"), "utf8");

const zones = [
  { id: "home", label: "Home", area: "Nahariya", kind: "home" },
  { id: "work", label: "Work", area: "Haifa", kind: "work" },
  { id: "family", label: "Family", area: "Nahariya", kind: "family" },
  { id: "route", label: "Route", area: "Nahariya → Haifa", kind: "route" },
];
const sensors = [
  { id: "official", label: "Official alert adapter", transport: "UNCONNECTED", source: "UNVERIFIED", freshness: "UNKNOWN" },
  { id: "secondary", label: "Secondary alert adapter", transport: "DEMO", source: "DEMO", freshness: "SIMULATED" },
  { id: "community", label: "Community/news adapter", transport: "DEMO", source: "DEMO", freshness: "SIMULATED" },
];
const PHASES = ["QUIET", "WATCH", "ACTIVE", "RESOLVED"];

const b64u = (x) => Buffer.from(x).toString("base64url");
const ub64u = (x) => Buffer.from(x, "base64url").toString("utf8");
function sign(payload) {
  const body = b64u(JSON.stringify(payload));
  const sig = createHmac("sha256", SECRET).update(body).digest("base64url");
  return `${body}.${sig}`;
}
function verify(token) {
  if (!token || typeof token !== "string" || !token.includes(".")) return null;
  const [body, sig] = token.split(".");
  const expected = createHmac("sha256", SECRET).update(body).digest("base64url");
  try {
    if (!timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
    const p = JSON.parse(ub64u(body));
    if (!Number.isInteger(p.phaseIndex) || !Number.isInteger(p.stateVersion)) return null;
    if (p.phaseIndex < 0 || p.phaseIndex >= PHASES.length) return null;
    return p;
  } catch { return null; }
}
function freshScenario() {
  return { scenarioId: randomUUID(), phaseIndex: 0, stateVersion: 1, resetCount: 0, lastTransitionId: null };
}
function scenarioFromToken(token) { return verify(token) ?? freshScenario(); }

function buildState(s) {
  const phase = PHASES[s.phaseIndex];
  const common = {
    product: "MONDAYID REALITY", promise: "Only what changes your reality.", mode: "SIMULATED",
    phase, scenarioId: s.scenarioId, stateVersion: s.stateVersion, resetCount: s.resetCount,
    stateToken: sign(s), generatedAt: new Date().toISOString(), zones, sensors,
    safetyNotice: "SIMULATED demo only. For real emergencies, rely on official Home Front Command alerts and current instructions.",
  };
  if (phase === "QUIET") return { ...common, headline: "Nothing has changed.", action: { code: "NONE", label: "Stay in routine" }, incident: null, delta: { kind: "NO_CHANGE", text: "No relevant change across saved zones." }, zoneStates: zones.map(z => ({ zoneId: z.id, state: "QUIET" })) };
  if (phase === "WATCH") return { ...common, headline: "Something may matter soon.", action: { code: "WATCH", label: "Keep official alerts audible" }, incident: { id: "demo-001", lifecycle: "NEW", title: "Unverified activity near the northern coastal corridor", truth: "REPORTED", relevance: ["home","route"], instruction: "No official action required. Keep official alerts audible.", provenance: [{ source:"Secondary alert adapter",label:"REPORTED",lineage:"DEMO_A"},{ source:"Community/news adapter",label:"REPORTED",lineage:"DEMO_B"}] }, delta: { kind:"NEW_RELEVANT_SIGNAL",text:"A weak signal became relevant to Home and Route." }, zoneStates: zones.map(z => ({ zoneId:z.id,state:["home","route"].includes(z.id)?"CHANGED":"QUIET" })) };
  if (phase === "ACTIVE") return { ...common, headline: "Go to protected space now.", action: { code:"MOVE",label:"Enter protected space" }, incident: { id:"demo-001",lifecycle:"ACTIVE",title:"Simulated official alert for Nahariya",truth:"OFFICIAL",relevance:["home","family"],instruction:"Enter a protected space now. Follow the current official Home Front Command instruction.",provenance:[{source:"Simulated official adapter",label:"OFFICIAL",lineage:"DEMO_OFFICIAL"},{source:"Secondary alert adapter",label:"REPORTED",lineage:"DEMO_A"}] }, delta:{kind:"ESCALATED",text:"WATCH → ACTIVE after a simulated authoritative alert."}, zoneStates:zones.map(z=>({zoneId:z.id,state:["home","family"].includes(z.id)?"ACTIVE":"QUIET"})) };
  return { ...common, headline:"The active incident ended.",action:{code:"VERIFY",label:"Follow current official instructions"},incident:{id:"demo-001",lifecycle:"RESOLVED",title:"Simulated incident resolved",truth:"OFFICIAL",relevance:["home","family"],instruction:"Return to routine only according to current official instructions.",provenance:[{source:"Simulated official adapter",label:"OFFICIAL",lineage:"DEMO_OFFICIAL"}]},delta:{kind:"RESOLVED",text:"ACTIVE → RESOLVED. Return to quiet only after resolution is verified."},zoneStates:zones.map(z=>({zoneId:z.id,state:"QUIET"})) };
}

const stateSchema = {
  product:z.string(),promise:z.string(),mode:z.literal("SIMULATED"),phase:z.enum(PHASES),scenarioId:z.string(),stateVersion:z.number().int(),resetCount:z.number().int(),stateToken:z.string(),generatedAt:z.string(),headline:z.string(),action:z.object({code:z.string(),label:z.string()}),zones:z.array(z.any()),sensors:z.array(z.any()),safetyNotice:z.string(),incident:z.any().nullable(),delta:z.object({kind:z.string(),text:z.string()}),zoneStates:z.array(z.any())
};
function textResult(state,text,withWidget=false){return{content:[{type:"text",text}],structuredContent:state,...(withWidget?{_meta:{"openai/widgetDescription":"MONDAYID REALITY shows only relevant changes, provenance, personal zones, actions, and sensor health."}}:{})}}
function createRealityServer(){
  const server=new McpServer({name:"mondayid-reality",version:VERSION},{instructions:"Never present simulated data as live. Official instructions outrank secondary reporting. Missing/degraded sensor data is never evidence of safety. Prefer discrete provenance labels over confidence percentages."});
  registerAppResource(server,"reality-widget-v3",WIDGET_URI,{},async()=>({contents:[{uri:WIDGET_URI,mimeType:RESOURCE_MIME_TYPE,text:widgetHtml,_meta:{ui:{prefersBorder:false,csp:{connectDomains:[],resourceDomains:[]}},"openai/widgetDescription":"A quiet personal safety surface. It expands only when saved reality changes and keeps provenance and sensor health inspectable."}}]}));
  server.registerTool("get_reality_state",{title:"Get Reality State",description:"Use this when you need the current MONDAYID REALITY simulated state as data without rendering the UI.",inputSchema:{stateToken:z.string().optional()},outputSchema:stateSchema,annotations:{readOnlyHint:true,destructiveHint:false,openWorldHint:false,idempotentHint:true}},async({stateToken})=>{const state=buildState(scenarioFromToken(stateToken));return textResult(state,`Reality state is ${state.phase}. SIMULATED demo data only.`)});
  registerAppTool(server,"render_reality",{title:"Open MondayID Reality",description:"Use this when the user wants to open the MONDAYID REALITY interactive safety surface.",inputSchema:{stateToken:z.string().optional()},outputSchema:stateSchema,annotations:{readOnlyHint:true,destructiveHint:false,openWorldHint:false,idempotentHint:true},_meta:{ui:{resourceUri:WIDGET_URI,visibility:["model","app"]},"openai/toolInvocation/invoking":"Opening Reality…","openai/toolInvocation/invoked":"Reality opened"}},async({stateToken})=>{const state=buildState(scenarioFromToken(stateToken));return textResult(state,`MONDAYID REALITY opened in ${state.phase}. SIMULATED demo data only.`,true)});
  registerAppTool(server,"transition_demo",{title:"Transition Reality Demo",description:"Use this only to advance or reset the clearly simulated MONDAYID REALITY scenario. Pass the signed stateToken from the current UI; transitionId makes retries safe.",inputSchema:{stateToken:z.string(),direction:z.enum(["next","reset"]),expectedVersion:z.number().int(),transitionId:z.string()},outputSchema:stateSchema,annotations:{readOnlyHint:false,destructiveHint:false,openWorldHint:false,idempotentHint:true},_meta:{ui:{visibility:["app","model"]}}},async({stateToken,direction,expectedVersion,transitionId})=>{
    const s=verify(stateToken); if(!s){const f=freshScenario();const state=buildState(f);return textResult(state,"Invalid or expired state token. A fresh simulated scenario was created.")}
    if(expectedVersion!==s.stateVersion){const state=buildState(s);return textResult(state,`Stale transition rejected. Current stateVersion is ${s.stateVersion}.`)}
    if(s.lastTransitionId===transitionId){const state=buildState(s);return textResult(state,`Duplicate transition ignored. State remains ${state.phase}.`)}
    const next={...s}; if(direction==="reset"){next.phaseIndex=0;next.resetCount+=1}else next.phaseIndex=(next.phaseIndex+1)%PHASES.length; next.stateVersion+=1; next.lastTransitionId=transitionId;
    const state=buildState(next); return textResult(state,`Simulation moved to ${state.phase}. No live alert data was used.`);
  });
  return server;
}

export default async function handler(req,res){
  const requestId=randomUUID(); const t0=Date.now();
  res.setHeader("cache-control","no-store");
  res.on?.("finish",()=>console.log(JSON.stringify({level:"info",requestId,method:req.method,url:req.url,status:res.statusCode,ms:Date.now()-t0})));
  const url=new URL(req.url||"/",`https://${req.headers.host||"localhost"}`); const route=url.searchParams.get("route");
  if(req.method==="GET" && route==="health"){res.statusCode=200;res.setHeader("content-type","application/json");return res.end(JSON.stringify({ok:true,product:"MONDAYID REALITY",version:VERSION,architecture:"stateless-signed-state",liveSafetyAdapters:0}))}
  if(req.method==="GET" && route==="root"){res.statusCode=200;res.setHeader("content-type","application/json");return res.end(JSON.stringify({name:"MONDAYID REALITY",version:VERSION,status:"demo",mcp:"/mcp",health:"/health"}))}
  if(req.method==="OPTIONS"){res.statusCode=204;res.setHeader("Access-Control-Allow-Origin","*");res.setHeader("Access-Control-Allow-Methods","POST, GET, DELETE, OPTIONS");res.setHeader("Access-Control-Allow-Headers","content-type, mcp-session-id, mcp-protocol-version");res.setHeader("Access-Control-Expose-Headers","Mcp-Session-Id");return res.end()}
  if(!["POST","GET","DELETE"].includes(req.method||"")){res.statusCode=405;return res.end("Method not allowed")}
  res.setHeader("Access-Control-Allow-Origin","*");res.setHeader("Access-Control-Expose-Headers","Mcp-Session-Id");
  const server=createRealityServer(); const transport=new StreamableHTTPServerTransport({sessionIdGenerator:undefined,enableJsonResponse:true});
  res.on?.("close",()=>{transport.close();server.close()});
  try{await server.connect(transport);await transport.handleRequest(req,res)}catch(error){console.error(JSON.stringify({level:"error",requestId,error:error instanceof Error?error.message:String(error)}));if(!res.headersSent){res.statusCode=500;res.setHeader("content-type","application/json");res.end(JSON.stringify({error:"internal_error",requestId}))}}
}
