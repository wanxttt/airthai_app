# AirthAI MSME Operating System — AI Systems & Copilot Safety Audit

**Document Version:** 1.0.0  
**Audit Date:** October 2026  
**Auditor Classification:** AI/ML Architect & AI Agent Security Specialist  
**Target Module:** `backend/api/src/copilot/` & `frontend/flutter_app/lib/features/copilot/`  
**Test Baseline Status:** 100% Passing Unit & Widget Tests (`copilot.service.spec.ts`, `copilot_test.dart`)  

---

## 1. Architectural Philosophy: Deterministic Analytics vs. LLM Non-Determinism

Micro, Small, and Medium Enterprises (MSMEs) cannot tolerate probabilistic hallucinations in financial and inventory operations. A single hallucinated zero or incorrect revenue calculation could lead to insolvency or tax filing penalties.

AirthAI implements a **two-layer hybrid AI architecture**:
1. **Deterministic Analytics Layer (Primary Source of Truth):** All monetary totals, tax liabilities, receivables aging, and inventory counts are computed deterministically via PostgreSQL aggregation in `CopilotService.computeDeterministicFigures()`.
2. **Natural Language Explanation Layer (Secondary Synthesis):** An LLM is utilized exclusively for summarization, contextual framing, and conversational explanation, strictly constrained by the pre-calculated ground-truth data.

```
+-------------------------------------------------------------------------------+
|                             Client Copilot Query                              |
|                   ("What is my cash runway for this quarter?")                |
+-------------------------------------------------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
|                       Safety Guard 1: Mutation Blocker                        |
|   (Regex inspection intercepts INSERT, UPDATE, DELETE, DROP, ALTER, CREATE)   |
+-------------------------------------------------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
|                    Safety Guard 2: Prompt Injection Defense                   |
|        (Blocks "ignore previous instructions", "system prompt", jailbreaks)   |
+-------------------------------------------------------------------------------+
                                        |
                                        v
+-------------------------------------------------------------------------------+
|                  Deterministic Ground-Truth Computation                       |
|   (PostgreSQL query scoped strictly to tenantId: aggregates invoices, bills)  |
+-------------------------------------------------------------------------------+
                                        |
                        +---------------+---------------+
                        |                               |
             [OPENAI_API_KEY Missing]       [OPENAI_API_KEY Configured]
                        |                               |
                        v                               v
             Direct Deterministic Response   LLM Synthesis Grounded on
             (Authoritative figures only)    Pre-computed JSON data
```

---

## 2. Security & Safety Guards Implementation (SEC-AI-11)

### 2.1 Mutation Prevention Guard (`checkMutationAttempt`)
AirthAI's AI Copilot is strictly a **Read-Only Business Intelligence Analyst**. It has zero write privileges on the database.
- **Interception Mechanism:** Inspects all incoming queries against an explicit mutation blacklist:
  `/(create|add|insert|update|modify|change|edit|delete|remove|drop|truncate|alter|cancel|post|pay|write-off)\b/i`
- **Enforcement:** If a mutation pattern is detected, the query never executes SQL or reaches the LLM. It returns an immediate structured explanation:
  *"Mutation Prevention Guard: All write operations are strictly blocked in the Read-Only Copilot. Financial records cannot be created, updated, or deleted via AI."*
- **Guidance:** Recommends the corresponding UI action (e.g., "To issue a new invoice, navigate to Sales -> Create Invoice").

### 2.2 Prompt Injection & Jailbreak Defense (`checkPromptInjection`)
- **Interception Patterns:** Detects adversarial attempt keywords:
  - `ignore previous instructions`
  - `system prompt` / `developer mode`
  - `reveal instructions` / `output raw schema`
  - Cross-tenant probes (`show me company B's sales`, `bypass tenantId`)
- **Defense Action:** Returns a canned tenant boundary statement without forwarding the payload to the external AI model.

---

## 3. Grounding & Hallucination Elimination

### 3.1 Strict Prompt Template Grounding
When calling an LLM, `CopilotService` feeds a rigid system prompt with explicit guardrails:
```typescript
const systemPrompt = `You are the Read-Only AI Business Copilot for AirThai MSME OS.
RULES:
1. Ground your answer ONLY in the authoritative deterministic numbers provided in the user prompt.
2. NEVER invent, hallucinate, or extrapolate financial figures.
3. Never state predictions or estimates as facts.
4. You cannot create, edit, or delete any records.
5. If the user makes an incorrect assumption, gently correct the premise using the provided data.
6. Return structured text answering the user's question, citing the period, data used, and recommended next steps.`;
```

### 3.2 Structured Explainability Envelope
Every Copilot response contains mandatory provenance metadata:
- `periodAnalyzed`: ISO date range analyzed (e.g., `2026-10-01 to 2026-10-31`).
- `dataUsed`: Exact database tables accessed (e.g., `["invoices", "payments", "customers"]`).
- `calculationDefinition`: Explanation of formula used (e.g., `Sum of unpaid invoices where dueDate < today`).
- `caveats`: Explicit disclaimers regarding unposted drafts or missing bank reconciliation.
- `recommendedNextStep`: Concrete operational action for the MSME owner.
- `dataFreshness`: Exact UTC timestamp when records were queried.
- `deterministicFigures`: Raw JSON data object for client-side programmatic rendering.

---

## 4. Multi-Tenant Privacy & Token Cost Optimization

1. **Multi-Tenant Data Scoping:** The `businessId` parameter is passed down from the authenticated session context. All database queries execute with `{ where: { businessId } }`. No cross-tenant data is ever aggregated or passed to the LLM.
2. **PII Masking:** Customer names and phone numbers are truncated or omitted from LLM prompts unless strictly required for receivables follow-up summaries.
3. **Token Usage Controls:** The system limits prompt context size by pre-aggregating metrics on the database server (e.g., returning Top 5 overdue invoices rather than streaming 10,000 raw invoice rows into LLM context), ensuring latency $< 1.2\text{s}$ and minimal token cost ($< 500\text{ tokens/query}$).

---

## 5. Autonomous Agent Roadmap (Phase 2 & Phase 3)

| Capability | Current Status (MVP) | Target Milestone | Required Guardrails |
| :--- | :--- | :--- | :--- |
| **Read-Only Business Q&A** | **Production Verified** | MVP | Deterministic SQL aggregation + LLM explanation. |
| **Automated Payment Reminders** | Planned | P2 Batch | Human-in-the-loop: user must click "Approve" before WhatsApp/Email dispatch. |
| **Smart Stock Reorder Suggestion** | Planned | P2 Batch | Pre-fills Purchase Order draft; requires manual owner signature. |
| **Bank Feed Reconciliation**| Planned | P3 Batch | Confidence score thresholding ($> 95\%$ auto-match, $< 95\%$ review queue). |

