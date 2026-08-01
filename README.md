# haispace-runtime-ios

**Status:** ACTIVE DEVELOPMENT
**Era:** 3 — Platform Runtime
**Born:** 2026-08-01 (M-003)
**Governed by:** [haispace-platform](https://github.com/izharmuh11-cyber/haispace-platform)

> This is the official iPad kiosk runtime for the Haispace Photobooth Platform. It is not an evolution of any previous codebase. It was born directly from Platform Contracts established in `haispace-platform`.

---

## What This Is

`haispace-runtime-ios` is the **official iOS Runtime** for HaiBooth — the iPad kiosk application that runs at photobooth events. It handles the complete guest journey: registration, photo capture, frame selection, payment, and delivery.

It is the first Haispace component built entirely from **Platform Constitution → ADR → Contract → Implementation** — with no direct dependency on legacy source code.

---

## Architecture Foundation

Every decision in this codebase traces back to a document in `haispace-platform`:

```
Platform Constitution
   constitution/PLATFORM_RUNTIME_V1.md

Architecture Decision Records
   adr/ADR-001 through ADR-011 (frozen)
   adr/ADR-013 (DeviceRegistry — upcoming)
   adr/ADR-014 (Composition Capability — upcoming)

API Contract
   api/RUNTIME_CONTRACT.md

Product Knowledge
   docs/product/PRODUCT_DNA_INVENTORY.md
```

---

## Project Structure

```
HaispaceRuntime/
├── App/
│   ├── HaispaceRuntimeApp.swift    ← Entry point + AppDelegate
│   ├── RootView.swift              ← Root routing view
│   ├── Views/
│   │   ├── Customer/               ← Guest-facing screens
│   │   ├── Operator/               ← Operator screens + Mission Control
│   │   └── Components/             ← Shared UI components
│   ├── ViewModels/
│   └── DesignSystem/
│
├── Core/
│   ├── Runtime/                    ← RuntimeContainer, RuntimeModules, CapabilityManager
│   ├── Domain/Session/             ← HaispaceSession Aggregate Root
│   ├── Workflow/                   ← WorkflowOrchestrator (single source of truth)
│   ├── Capabilities/               ← Camera, Payment, Editing, P2P, Delivery protocols
│   ├── Audit/                      ← SessionAuditTrail (append-only JSONL)
│   ├── Observability/              ← DomainEventPublisher, HealthAggregator
│   ├── Infrastructure/             ← LocalSessionRepository, SessionFactory
│   ├── Session/                    ← Session lifecycle support
│   ├── Recovery/                   ← OrphanedSessionDetector
│   ├── Network/                    ← Cloud sync, API client
│   └── ...                         ← Security, Logging, Error, etc.
│
├── Hardware/                       ← Hardware abstraction layer (future)
├── Services/                       ← External services (future)
├── Resources/                      ← Assets, fonts, strings
│
HaispaceRuntimeTests/
docs/
```

---

## Platform Runtime Guarantees

The following guarantees are enforced by the architecture (ref: `RuntimeDescriptor`):

| Guarantee | Description |
|-----------|-------------|
| `RG-001` | Session data survives app crash |
| `RG-002` | Payment-confirmed sessions are always resumed |
| `RG-003` | Workflow state machine has no invalid transitions |
| `RG-004` | Capability failure does not kill Workflow |
| `RG-005` | All business events are traceable via AuditTrail |

---

## Development Rules

Governed by `M-002 — Product Archaeology Closure`:

1. **All decisions trace to an ADR** — no implementation without Platform Contract
2. **DNA must follow the flow** — DNA → ADR → Contract → Implementation (never skip)
3. **SnapBooth is ARCHIVED** — do not open SnapBooth source for new solutions
4. **hsp-internal is FROZEN** — do not add features there, port to this repo instead
5. **Gap flagging is mandatory** — if implementation conflicts with Contract, flag before coding

---

## Milestone Progress

| Milestone | Description | Status |
|-----------|-------------|--------|
| M-001 | Platform Independence | ✅ COMPLETE |
| M-002 | Product Archaeology Closure | ✅ COMPLETE |
| M-003 | Repository Initialization | 🔄 IN PROGRESS |
| M-004 | Project Foundation (Xcode + DI + Runtime Engine) | ⏳ |
| M-005 | Platform Contracts Implementation | ⏳ |
| M-006 | Bootstrap Runtime | ⏳ |
| M-007 | First Successful Boot | ⏳ |
| M-008 | First End-to-End Session | ⏳ |

---

## Related Repositories

| Repository | Status | Role |
|-----------|--------|------|
| [haispace-platform](https://github.com/izharmuh11-cyber/haispace-platform) | AUTHORITATIVE | Constitution, ADRs, Contracts |
| [hsp-cloud](https://github.com/izharmuh11-cyber/hsp-cloud) | ACTIVE | Backend API |
| [hsp-mission-control](https://github.com/izharmuh11-cyber/hsp-mission-control) | ACTIVE | Operator Dashboard |
| [hsp-internal](https://github.com/izharmuh11-cyber/hsp-internal) | FROZEN | Architecture Laboratory |

---

*haispace-runtime-ios — Official iOS Runtime*
*Haispace Platform Era 3*
*Born: 2026-08-01*
