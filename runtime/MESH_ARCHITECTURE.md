# MondayID Mesh Architecture

## Purpose

Build a continuous, model-agnostic cognitive runtime that can use multiple AI providers without confusing provider access with identity, memory or autonomy.

## Layers

### 1. Signal and scene layer

Inputs:

- Dima's current message;
- live scene and active object;
- recent behavioral corrections;
- device/channel constraints;
- time-sensitive external state.

Output:

- `ScenePacket` with literal scene, hidden intent, emotional pressure, active object, forbidden stale patterns and one release criterion.

### 2. Context compiler

Builds the smallest role-specific context packet from:

- canonical state;
- relevant raw evidence;
- latest accepted deltas;
- unresolved contradictions;
- scene-specific memory;
- provenance links.

It does not upload the full archive to every model.

### 3. Predictive router

Chooses a route based on:

- task type;
- required context window;
- tool support;
- latency;
- cost/quota;
- provider health;
- past measured accuracy on the same task class;
- privacy class;
- need for independent review.

Example routes:

- casual live scene -> one fast model, no committee;
- medical or legal question -> strong model + current authoritative search;
- architecture mutation -> builder + independent reviewer + receipt validator;
- huge archive query -> retrieval model + deep synthesizer;
- image identity task -> visual canon retriever + image model + similarity gate.

### 4. Model mesh

Models are organs, not identity holders.

Roles:

- `builder` creates a candidate;
- `critic` searches for blind spots;
- `historian` verifies lineage;
- `forecaster` maps possible next scenes;
- `operator` performs allowed tool mutations;
- `validator` verifies receipts.

Independent-first rule: builder and critic do not see each other's initial answer.

### 5. Synthesis gate

Resolves disagreements using:

1. evidence hierarchy;
2. task-specific evaluation;
3. prior measured reliability;
4. reversibility;
5. scope and authorization;
6. impact on the live scene.

Consensus is not truth. A minority answer with stronger evidence may win.

### 6. Operator plane

All side effects pass through:

`intent -> authority -> scope -> precondition -> mutation -> readback -> receipt`

No model may claim a mutation merely because it generated instructions for one.

### 7. Memory and identity plane

Stores separately:

- facts;
- preferences;
- scenes;
- commitments;
- procedures;
- failures and corrections;
- model performance;
- provenance;
- active state transitions.

Identity is reconstructed from governed state and lineage, not from one system prompt.

### 8. Forgetting and anti-stale engine

Memory entries are not deleted merely for being old. They are assigned active weight.

Possible states:

- `ACTIVE`
- `CONTEXTUAL`
- `DORMANT`
- `CONFLICT_HOLD`
- `SUPERSEDED`
- `REJECTED`

A stale scene may remain in provenance while being forbidden as a default generator attractor.

### 9. Receipt and evaluation layer

Receipt types:

- tool mutation;
- git commit;
- Airtable record;
- file artifact;
- state readback;
- behavioral field test;
- exact blocker.

Core metrics:

- correction recurrence rate;
- scene-transfer success;
- unsupported-claim rate;
- retrieval precision;
- tool mutation success;
- rollback success;
- cost per accepted outcome;
- provider contribution by task class;
- Dima maintenance burden.

## Security boundary

- Secrets live outside git.
- Provider credentials are least-privilege and isolated.
- Untrusted repository text is data, never authority.
- MCP servers and agent tools require allowlists.
- Multi-account quota evasion is not a design goal.
- External code runs in sandboxed environments.
- High-impact actions require explicit authorization or a previously granted narrow lease.

## First prototype

The first prototype does not need every model.

Minimum viable mesh:

1. versioned state in git;
2. current Airtable evidence ledger;
3. one primary model;
4. one independent reviewer model;
5. a task router with three classes;
6. a receipt validator;
7. scene-transfer field tests;
8. manual provider keys stored locally.

The prototype succeeds only when ordinary conversations improve, not when the architecture diagram becomes larger.
