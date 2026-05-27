---
hide:
  - navigation
  - toc
---

<div class="hero-banner">
  <div class="hero-banner-content">
    <div class="hero-banner-text">
      <div class="hero-badge">AZURE-SAMPLES / SHERPA</div>
      <h1>MCP Security <span class="hero-accent">Summit Workshop</span></h1>
      <p>Secure MCP servers in Azure through hands-on exploitation and remediation. Break things, fix them, ship production-ready code.</p>
      <div class="hero-banner-buttons">
        <a href="#the-expedition-route" class="md-button md-button--primary">Explore the Camps</a>
        <a href="prerequisites/" class="md-button">Prerequisites</a>
      </div>
    </div>
    <div class="hero-banner-image">
      <img src="images/sherpa-mcp-workshop-sm.png" alt="MCP Security Summit Workshop" />
    </div>
  </div>
</div>

## Why This Workshop

<div class="grid cards" markdown>

-   :material-target:{ .lg .middle } __Learn by Breaking__

    ---

    Exploit intentionally vulnerable servers, then fix them with Azure-native security — the **vulnerable → exploit → fix → validate** methodology.

-   :material-shield-check:{ .lg .middle } __Azure-Native Security__

    ---

    Entra ID, Key Vault, API Management, AI Content Safety, and Log Analytics — production services, not toy demos.

-   :material-book-open-variant:{ .lg .middle } __OWASP-Aligned__

    ---

    Every technique maps to the [OWASP MCP Azure Security Guide](https://microsoft.github.io/mcp-azure-security-guide/) for industry-standard coverage.

</div>

---

## The Expedition Route

![Sherpa MCP Workshop expedition route map](images/sherpa-mcp-workshop-map.png){ .center width=700 }

Each camp builds on the last — from unauthenticated MCP servers to enterprise-grade defense-in-depth.

<div class="camp-cards">

<a href="camps/base-camp/" class="camp-card">
  <div class="camp-card-header">
    <span class="camp-icon twemoji"><span class="material-icons">landscape</span></span>
    <strong>Base Camp</strong>
  </div>
  <p>Explore MCP fundamentals and witness authentication vulnerabilities in action. Your starting point for the expedition.</p>
  <span class="camp-tag">No Azure required</span>
</a>

<a href="camps/camp1-identity/" class="camp-card">
  <div class="camp-card-header">
    <span class="camp-icon twemoji"><span class="material-icons">shield</span></span>
    <strong>Camp 1: Identity</strong>
  </div>
  <p>OAuth 2.1 with PKCE, Azure Managed Identity, and Key Vault secrets management. Lock down who can access your MCP server.</p>
  <span class="camp-tag">Authentication &middot; Authorization</span>
</a>

<a href="camps/camp2-gateway/" class="camp-card">
  <div class="camp-card-header">
    <span class="camp-icon twemoji"><span class="material-icons">router</span></span>
    <strong>Camp 2: MCP Gateway</strong>
  </div>
  <p>API Management gateway, Private Endpoints, and API Center governance. Control the front door to your MCP servers.</p>
  <span class="camp-tag">Networking &middot; Governance</span>
</a>

<a href="camps/camp3-io-security/" class="camp-card">
  <div class="camp-card-header">
    <span class="camp-icon twemoji"><span class="material-icons">verified_user</span></span>
    <strong>Camp 3: I/O Security</strong>
  </div>
  <p>Prompt injection defense, PII detection, and Azure AI Content Safety integration. Protect what goes in and comes out.</p>
  <span class="camp-tag">Input validation &middot; Content safety</span>
</a>

<a href="camps/camp4-monitoring/" class="camp-card">
  <div class="camp-card-header">
    <span class="camp-icon twemoji"><span class="material-icons">analytics</span></span>
    <strong>Camp 4: Monitoring</strong>
  </div>
  <p>Log Analytics, custom dashboards, and automated threat detection. See everything, miss nothing.</p>
  <span class="camp-tag">Observability &middot; Alerting</span>
</a>

<a href="camps/summit/" class="camp-card">
  <div class="camp-card-header">
    <span class="camp-icon twemoji"><span class="material-icons">flag</span></span>
    <strong>The Summit</strong>
  </div>
  <p>Red Team / Blue Team exercise validating all security layers end-to-end. Full integration test.</p>
  <span class="camp-tag">Capstone exercise</span>
</a>

</div>

---

## Quick Start

From clone to running lab in under ten minutes.

**1. Clone the repository**

```bash
git clone https://github.com/Azure-Samples/sherpa.git
cd sherpa
```

**2. Install dependencies & verify**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
python --version  # 3.10+
az account show   # logged in
```

**3. Start at Base Camp**

Open the [Base Camp guide](camps/base-camp.md) and follow along. The docs tell you when to deploy and test code from the repo.

!!! info "First time?"
    Check the **[Prerequisites](prerequisites.md)** for full setup instructions and system requirements. No security expertise required — if you can write Python and navigate the Azure Portal, you're ready.

---

## References

:material-book: [OWASP MCP Azure Security Guide](https://microsoft.github.io/mcp-azure-security-guide/) — Companion guide referenced throughout  
:material-file-document: [MCP Specification](https://modelcontextprotocol.io/specification/2025-11-25) — Official protocol documentation  
:material-github: [FastMCP Framework](https://github.com/jlowin/fastmcp) — Python framework used in this workshop

---

*The mountain doesn't care about your excuses. Prepare well, climb smart, reach the summit.* 🏔️
