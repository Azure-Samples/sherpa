---
hide:
  - toc
---

# Section 3: Network Security

In this final section, you'll learn about network isolation patterns to protect your MCP backends in production.

???+ note "Understanding Network Isolation for MCP Servers"

    ### The Security Challenge: Direct Backend Access

    **OWASP Risk:** [MCP-04 (Software Supply Chain Attacks & Dependency Tampering)](https://microsoft.github.io/mcp-azure-security-guide/mcp/mcp04-supply-chain/)

    Your MCP servers are running in Container Apps with public endpoints. While you've added OAuth, rate limiting, and content safety at the gateway, there's a fundamental problem:

    **Anyone who discovers your Container App URL can bypass APIM entirely.**

    ```
    https://sherpa-mcp-server.xxxxxxx.xxxxx.azurecontainerapps.io
    ```

    This URL isn't secret—it follows Azure's predictable naming pattern. An attacker who finds it can:

    - **Bypass OAuth** — Call the backend directly without authentication
    - **Bypass rate limiting** — Send unlimited requests
    - **Bypass content safety** — Submit malicious prompts without filtering
    - **Avoid detection** — Requests won't appear in your APIM logs
    - **Run up costs** — Direct calls still consume your compute resources

    All the security you built in Sections 1 and 2 becomes optional if backends are publicly accessible.

    ---

    ### The Solution: Network Isolation

    The fix is straightforward in concept: **only allow traffic from APIM to reach your backends**. In practice, there are several ways to achieve this:

    ??? tip "Option 1: IP Restrictions (Simple but Limited)"
        
        Container Apps support IP-based access restrictions. You can configure an allow-list that only permits APIM's IP:

        ```bash
        # Allow only APIM's IP (everything else implicitly denied)
        az containerapp ingress access-restriction set \
          --name sherpa-mcp-server \
          --resource-group $RG \
          --rule-name "allow-apim" \
          --ip-address "${APIM_OUTBOUND_IP}/32" \
          --action Allow
        ```

        **Limitation:** APIM Basic v2 (used in this workshop) has dynamic outbound IPs that can change during scaling or maintenance. This approach works better with **APIM Standard v2**, which provides static outbound IPs.

    ??? tip "Option 2: Virtual Network Integration (Recommended for Production)"
        
        For true network isolation, deploy both APIM and Container Apps inside an Azure Virtual Network. APIM faces the public internet while Container Apps are internal-only with no public IP. Traffic stays within Azure's backbone, and you can add NSGs for defense in depth.

        **Benefits:**
        
        - Container Apps have no public IP at all
        - Traffic stays within Azure's backbone
        - Defense in depth with NSGs

    ??? tip "Option 3: Private Endpoints"
        
        Use Azure Private Link to expose your Container Apps only via private endpoints:

        - APIM connects to backends via private IP
        - No public internet traversal
        - Can combine with VNet for full isolation

    ??? tip "Option 4: Header-Based Validation"
        
        Add a custom header in APIM that backends validate:

        **APIM Policy:**
        ```xml
        <set-header name="X-APIM-Gateway-Token" exists-action="override">
          <value>{{gateway-secret}}</value>
        </set-header>
        ```

        **Backend validation:**
        ```python
        if request.headers.get("X-APIM-Gateway-Token") != EXPECTED_TOKEN:
            return Response("Forbidden", status=403)
        ```

        This works with dynamic IPs but requires code changes in your MCP server.

    ---

    ### What This Means for Your Deployment

    For this workshop, we've focused on the security controls that run **at the gateway layer**—OAuth, rate limiting, and content safety. These provide significant protection and are the most impactful first steps.

    **Network isolation is the final layer** that ensures attackers can't simply bypass your gateway. When planning your production deployment, choose the approach that fits your requirements:

    | Approach | Complexity | Cost | APIM Tier Required |
    |----------|------------|------|-------------------|
    | IP Restrictions | Low | None | Standard v2+ (static IPs) |
    | VNet Integration | Medium | VNet costs | Standard v2, Premium v2 |
    | Private Endpoints | Medium | Private Link costs | Developer, Basic, Standard, Standard v2, Premium, Premium v2 |
    | Header Validation | Low | None | Any |

    ---

    ### Key Takeaways

    1. **Gateway security is necessary but not sufficient** — Without network isolation, all your APIM policies can be bypassed.

    2. **Defense in depth matters** — Layer network controls on top of application-level security.

    3. **Choose the right approach for your tier** — IP restrictions need static IPs; VNet integration when possible.

    4. **Monitor for direct access attempts** — Even with restrictions, log and alert on unexpected traffic patterns.

    **OWASP MCP-04 awareness complete!** :material-check:

---

## Summary

You've deployed a production-grade API gateway for MCP servers. Here's what you built:

| Control | OWASP Risk | Page |
|---------|------------|------|
| OAuth + PRM (RFC 9728) | MCP-07: Insufficient Authentication | [Gateway & Authentication](section1-gateway-governance.md) |
| Rate Limiting | MCP-02: Privilege Escalation via Scope Creep | [Gateway & Authentication](section1-gateway-governance.md) |
| Prompt Shields | MCP-06: Prompt Injection | [Content Safety](section2-content-safety.md) |
| API Center | MCP-09: Shadow MCP Servers | [API Governance](api-governance.md) |
| Network Isolation | MCP-04: Supply Chain Attacks | [Network Security](#) (this page) |

### Key Takeaways

- **Gateway pattern** centralizes security—update policies without redeploying servers
- **RFC 9728 (PRM)** enables automatic OAuth discovery for MCP clients
- **Policy fragments** make security controls reusable across APIs
- **Defense in depth**: identity → rate limits → content filtering → network isolation

??? tip "Production Readiness Checklist"
    - Upgrade to **APIM Standard v2** for static IPs
    - Enable **Virtual Network integration** for full isolation
    - Configure **Azure Monitor alerts** for auth failures and rate limit violations
    - Set up **RBAC for API Center** for team self-service
    - Establish **cost monitoring** with Azure Cost Management

---

## Cleanup

When you're done with Camp 2, remove all Azure resources:

```bash
# Delete all resources
azd down --force --purge
```

!!! warning "This deletes everything"
    The `azd down` command will delete all Azure resources provisioned for this camp, including the APIM gateway, Container Apps, Content Safety, and API Center. Make sure you've completed all the waypoints you want to explore before running cleanup.

**Optional:** Delete the Entra ID applications:

```bash
# Get app IDs
MCP_APP_ID=$(azd env get-value MCP_APP_CLIENT_ID)
APIM_APP_ID=$(azd env get-value APIM_CLIENT_APP_ID)

# Delete apps
az ad app delete --id $MCP_APP_ID
az ad app delete --id $APIM_APP_ID
```

---

## What's Next?

!!! success "Camp 2 Complete!"
    You've secured your MCP servers with enterprise-grade API gateway controls!

Your gateway now handles identity, rate limiting, content safety, and API governance. Next, you'll turn your attention to the MCP servers themselves and ensure the data flowing in and out is properly validated and sanitized.

[Continue: Camp 3 →](../camp3-io-security.md){ .md-button .md-button--primary }

← [Content Safety](section2-content-safety.md) | [Camp 3: I/O Security →](../camp3-io-security.md)
