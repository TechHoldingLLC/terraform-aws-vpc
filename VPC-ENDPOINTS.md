# Understanding VPC Endpoints

A plain-language guide to Gateway and Interface VPC endpoints — what they are, why they
exist, when each one makes sense, and how the pieces (subnets, route tables, security
groups, DNS) fit together.

This guide is written against the `gateway_endpoints` / `interface_endpoints` support in
this module, so the last section maps every concept back to a module variable.

---

## Table of contents

1. [The problem endpoints solve](#1-the-problem-endpoints-solve)
2. [The two types at a glance](#2-the-two-types-at-a-glance)
3. [Gateway endpoints in detail](#3-gateway-endpoints-in-detail)
4. [Interface endpoints in detail](#4-interface-endpoints-in-detail)
5. [Where do endpoints live? Public vs private subnets](#5-where-do-endpoints-live-public-vs-private-subnets)
6. [Why security groups (and why only for Interface)](#6-why-security-groups-and-why-only-for-interface)
7. [DNS — the part that confuses everyone](#7-dns--the-part-that-confuses-everyone)
8. [Which services support which type](#8-which-services-support-which-type)
9. [Cost](#9-cost)
10. [Endpoint policies](#10-endpoint-policies)
11. [Decision guide](#11-decision-guide)
12. [Common gotchas](#12-common-gotchas)
13. [Troubleshooting checklist](#13-troubleshooting-checklist)
14. [How this maps to this module](#14-how-this-maps-to-this-module)

---

## 1. The problem endpoints solve

Every AWS service (S3, DynamoDB, ECR, CloudWatch Logs, SSM, Secrets Manager…) is reached
through a **public API hostname**, like:

```
s3.us-east-1.amazonaws.com
logs.us-east-1.amazonaws.com
api.ecr.us-east-1.amazonaws.com
```

"Public hostname" means DNS resolves it to a **public IP address**. So even though the
service is AWS's own, talking to it looks — to your VPC's routing — exactly like talking to
the internet.

That creates a problem for private subnets. A private subnet, by definition, has no route
to an internet gateway. So an instance there **cannot reach any AWS API at all** unless you
give it a path out:

```
private subnet instance  ->  NAT gateway  ->  internet gateway  ->  s3.us-east-1.amazonaws.com
                             ^^^^^^^^^^^
                             costs money, per-hour + per-GB
```

This works, but it has three real downsides:

1. **You pay twice.** NAT gateway hourly charge, plus a per-GB data processing charge on
   everything that passes through. Pulling a 2 GB container image from ECR on every deploy
   adds up fast.
2. **You need the NAT at all.** A workload that only ever talks to AWS APIs still forces you
   to run and pay for a NAT gateway.
3. **Your traffic takes a public path.** It stays on the AWS backbone and never touches the
   actual internet, but from a compliance point of view it leaves your VPC and travels to a
   public IP address. Many security reviews object to this.

**A VPC endpoint fixes all three.** It creates a private doorway from your VPC directly to
an AWS service, so traffic never needs a NAT, never routes to a public IP, and never leaves
your VPC's private address space.

There are two completely different mechanisms for doing this, and that's why there are two
types of endpoint.

---

## 2. The two types at a glance

|                                  | **Gateway endpoint**                    | **Interface endpoint**                       |
| -------------------------------- | --------------------------------------- | -------------------------------------------- |
| How it works                     | A route in your route table             | An ENI (network card) with a private IP      |
| What you attach it to            | Route tables                            | Subnets                                      |
| Supported services               | **Only S3 and DynamoDB**                | ~200 AWS services + third-party PrivateLink  |
| Cost                             | **Free**                                | Hourly per AZ + per GB processed             |
| Has its own security group       | No                                      | **Yes** — and you must configure it          |
| Changes DNS resolution           | No                                      | Optionally (and you almost always want it)   |
| Uses AWS PrivateLink             | No                                      | Yes                                          |
| Reachable from on-premises       | **No**                                  | Yes (via VPN / Direct Connect)               |
| Reachable from a peered VPC      | **No**                                  | Yes                                          |
| Reachable from another Region    | No                                      | Yes (cross-region endpoints)                 |
| Uses an IP from your subnet CIDR | No                                      | Yes, one per subnet                          |

The short version: **Gateway is free but only works for two services and only from inside
the VPC. Interface costs money but works for almost everything and from almost anywhere.**

---

## 3. Gateway endpoints in detail

### How it actually works

A gateway endpoint does **not** create any hardware, IP address, or network card. It works
purely by **routing**.

When you create one, AWS adds a route to each route table you select:

| Destination                 | Target                    |
| --------------------------- | ------------------------- |
| `pl-63a5400a` (prefix list) | `vpce-0abc123` (endpoint) |

That `pl-…` thing is an **AWS-managed prefix list** — just a named, auto-updated list of all
the public IP ranges that S3 (or DynamoDB) uses in this Region. AWS maintains it; you never
edit it.

So the flow is:

```
  ┌─────────────────── your VPC ───────────────────┐
  │                                                │
  │  private subnet                                │
  │  ┌──────────┐                                  │
  │  │ instance │  "GET s3.us-east-1.amazonaws.com"│
  │  └────┬─────┘                                  │
  │       │ 1. DNS still returns a PUBLIC IP       │
  │       │    (52.216.x.x) — unchanged!           │
  │       ▼                                        │
  │  ┌─────────────────┐                           │
  │  │ route table     │ 2. dest 52.216.x.x matches│
  │  │ pl-63a5400a ──▶ │    the S3 prefix list, so │
  │  │   vpce-0abc123  │    it routes to the       │
  │  └────────┬────────┘    endpoint, NOT the NAT  │
  │           │                                    │
  └───────────┼────────────────────────────────────┘
              ▼
        ┌───────────┐
        │    S3     │   3. never touches NAT or IGW
        └───────────┘
```

The key insight, and the thing that surprises people: **DNS does not change.** Your instance
still resolves `s3.us-east-1.amazonaws.com` to a public IP, and still *sends* packets to
that public IP. The route table quietly intercepts them by IP range and hands them to the
endpoint instead of the NAT gateway.

This is why gateway endpoints need no DNS setting and no security group of their own —
there's no device to secure and no hostname to override.

### It only works for S3 and DynamoDB

That's the whole list. From the AWS docs:

> Gateway VPC endpoints provide reliable connectivity to Amazon S3 and DynamoDB without
> requiring an internet gateway or a NAT device for your VPC.

If you want a private path to any other service, you need an interface endpoint.

### It's free

> There is no additional charge for using gateway endpoints.

No hourly charge, no per-GB charge. This is why **you should essentially always create an S3
gateway endpoint** if you have private subnets — it is free money. Every GB your app pulls
from S3 through a NAT costs you NAT data processing; through a gateway endpoint it costs
nothing.

### Route precedence (why it "just works")

Route tables use **longest prefix match** — the most specific route wins. Your private route
table has both:

```
0.0.0.0/0      -> nat-gateway     (very broad)
pl-63a5400a    -> vpce-0abc123    (specific S3 ranges)
```

S3-bound traffic matches the specific prefix list and takes the endpoint. Everything else
falls through to `0.0.0.0/0` and takes the NAT. You don't have to remove or reorder
anything — adding the endpoint is safe.

Two consequences worth knowing:

- **Cross-region S3 still uses the NAT.** Prefix lists are per-Region. If your app in
  `us-east-1` writes to a bucket in `eu-west-1`, that traffic doesn't match the local prefix
  list and goes out the NAT as usual.
- Route tables *not* associated with the endpoint are unaffected. Instances in those subnets
  keep using the public path. This is why the endpoint is scoped to route tables, which
  brings us to…

### It's scoped to route tables, not subnets

> All instances in the subnets associated with a route table associated with a gateway
> endpoint automatically use the gateway endpoint to access the service. Instances in subnets
> that aren't associated with these route tables use the public service endpoint.

So "who gets to use this endpoint" is decided entirely by which route tables you attach it
to. In this module that's the private route tables — see [section 14](#14-how-this-maps-to-this-module).

### What gateway endpoints cannot do

This is the main reason to reach for an interface endpoint instead:

- **Not reachable from on-premises** over VPN or Direct Connect.
- **Not reachable from a peered VPC.**
- **Not reachable through a Transit Gateway.**
- **Not reachable from another Region.**

A gateway endpoint only serves traffic originating in the VPC that owns it. That makes sense
once you understand the mechanism — it's a route in *that VPC's* route tables, and a route
table only affects traffic originating in its own subnets.

---

## 4. Interface endpoints in detail

### How it actually works

An interface endpoint is a real thing on your network: an **ENI** (Elastic Network
Interface — a virtual network card) placed in each subnet you choose, each taking a private
IP from that subnet's CIDR.

```
  ┌───────────────────── your VPC 10.0.0.0/16 ─────────────────────┐
  │                                                                │
  │  private subnet 10.0.100.0/24    private subnet 10.0.101.0/24   │
  │  ┌──────────┐                    ┌──────────┐                  │
  │  │ instance │                    │ instance │                  │
  │  └────┬─────┘                    └────┬─────┘                  │
  │       │                               │                        │
  │       ▼                               ▼                        │
  │  ┌─────────────┐               ┌─────────────┐                 │
  │  │ ENI         │               │ ENI         │  <- the endpoint│
  │  │ 10.0.100.50 │               │ 10.0.101.50 │     itself      │
  │  │ [ sec grp ] │               │ [ sec grp ] │                 │
  │  └──────┬──────┘               └──────┬──────┘                 │
  └─────────┼─────────────────────────────┼────────────────────────┘
            └──────────────┬──────────────┘
                           ▼
                  ┌─────────────────┐
                  │  CloudWatch Logs│  (via AWS PrivateLink)
                  └─────────────────┘
```

Because it's a real network interface with a private IP inside your subnet:

- It **consumes an IP** from each subnet's CIDR (plan your subnet sizes accordingly).
- It **has a security group**, because it's a network interface and every ENI in a VPC has
  one. This is yours to configure.
- It can be reached by **anything that can route to that private IP** — including on-prem
  over VPN/Direct Connect, peered VPCs, and Transit Gateway. This is the big functional
  advantage over gateway endpoints.
- You should create it in **every AZ you run workloads in**, both for availability and to
  avoid cross-AZ data transfer charges.

### High availability

Each ENI lives in one AZ. If you put the endpoint in only one subnet and that AZ has
problems, workloads in other AZs lose access to the service. Always place interface
endpoints in a subnet per AZ — this module does that automatically.

### It changes DNS (if you let it)

This is the single most important setting on an interface endpoint, and it gets its own
section below. See [section 7](#7-dns--the-part-that-confuses-everyone).

---

## 5. Where do endpoints live? Public vs private subnets

### Gateway endpoints: neither — they attach to route tables

There's no device to place, so the question is only *which route tables* get the route.

- **Private route tables** — the normal choice. This is the whole point: give private
  subnets a free, NAT-free path to S3/DynamoDB.
- **Public route tables** — optional. Instances in public subnets already reach S3 through
  the internet gateway, and IGW traffic to S3 in the same Region is free, so adding the
  endpoint here saves little. It's not harmful, just usually unnecessary.

This module attaches gateway endpoints to the **private route tables only**.

### Interface endpoints: private subnets

Put the ENIs in **private subnets**. Reasons:

1. The endpoint doesn't need to be reachable from the internet — it serves callers *inside*
   your network. A public subnet gives it nothing.
2. Your workloads that need it are usually in private subnets already, so you get
   same-AZ, same-subnet traffic.
3. Public subnets are for things that need inbound internet reachability. An endpoint isn't
   one of those.

This module **requires** private subnets for interface endpoints — setting
`interface_endpoints` without `create_private_subnets = true` fails the plan. Putting the
ENI in a public subnet is not a milder version of the same thing: that subnet already
reaches the service over the internet gateway at no charge, so the endpoint would add an
hourly fee plus per-GB processing and buy you nothing.

You do *not* need a NAT for this. `create_private_subnets = true` with no `nat_type` gives
you private subnets whose route table has no default route at all — fully isolated, reaching
AWS APIs through endpoints only. That is the cheapest and tightest configuration this module
can build, and the one interface endpoints exist for.

> **Note:** "private subnet" here just means a subnet whose route table has no `0.0.0.0/0`
> route to an internet gateway. Endpoints work fine in a subnet with *no* internet route at
> all — that's the ideal case, and the reason you can run a fully isolated subnet that still
> reaches AWS APIs.

---

## 6. Why security groups (and why only for Interface)

### Gateway endpoints have no security group

There's no ENI, so there's nothing to attach a security group to. But there *is* a security
detail people miss:

> When your instances access Amazon S3 or DynamoDB through a gateway endpoint, they access
> the service using its public endpoint. The security groups for these instances must allow
> traffic to and from the service.

Read that carefully. The **endpoint** has no security group, but your **instance's** security
group still needs to allow outbound traffic to S3's IP ranges. If your instance SG has a
restrictive egress rule, add the prefix list as a destination:

| Destination                 | Protocol | Port |
| --------------------------- | -------- | ---- |
| `pl-63a5400a` (prefix list) | TCP      | 443  |

Most setups use "allow all egress" and never notice this. If you lock down egress, this is a
classic cause of "the endpoint exists but nothing works."

The same applies to **NACLs** on those subnets — and NACLs can't reference prefix lists, so
you'd have to list the actual CIDRs.

### Interface endpoints need a security group — and it's a real access control

The endpoint's ENI is what your callers connect to, over **HTTPS on port 443**. Its security
group decides *who is allowed to use the endpoint at all*.

A minimal, sensible rule set:

| Direction | Protocol | Port | Source / Destination      |
| --------- | -------- | ---- | ------------------------- |
| Inbound   | TCP      | 443  | your VPC CIDR (or an app SG) |
| Outbound  | all      | all  | anywhere                  |

Only 443 is needed because every AWS API is HTTPS. That's what this module creates by
default: **inbound TCP/443 from the VPC CIDR**.

**Why this matters more than it looks:** if you also enable private DNS (which you normally
do), this security group becomes the *only* thing standing between your workloads and the
service. See the warning in the next section.

You can tighten this to specific application security groups instead of the whole VPC CIDR —
that's good practice for sensitive services. Just remember that anything you exclude loses
access to the service entirely.

---

## 7. DNS — the part that confuses everyone

An interface endpoint **always** gets its own hostnames, whatever you configure:

```
Regional:  vpce-0abc123-xyz.logs.us-east-1.vpce.amazonaws.com          -> all ENI IPs
Zonal:     vpce-0abc123-xyz-us-east-1a.logs.us-east-1.vpce.amazonaws.com -> one ENI IP
```

Those work immediately, but nothing uses them by default, because your code calls the
*normal* hostname (`logs.us-east-1.amazonaws.com`). The `private_dns_enabled` setting decides
what that normal hostname resolves to.

### `private_dns_enabled = false`

```
app: PutLogEvents -> logs.us-east-1.amazonaws.com
       │
       ├─ DNS -> 52.94.x.x   (AWS PUBLIC IP — unchanged)
       │
       └─ needs a 0.0.0.0/0 route -> NAT gateway -> internet gateway
```

The endpoint exists, has ENIs, and costs money — but **carries zero traffic**. Your app is
still going out through the NAT. And if there's no NAT at all, the call simply **times out**.

To actually use it you must point every client at the endpoint's own hostname:

```bash
aws logs describe-log-groups \
  --endpoint-url https://vpce-0abc123-xyz.logs.us-east-1.vpce.amazonaws.com
```

…or build a Route53 private hosted zone yourself that aliases the real hostname to the
endpoint. Which is exactly the work that `true` does for you.

### `private_dns_enabled = true`  ← what you normally want

```
app: PutLogEvents -> logs.us-east-1.amazonaws.com
       │
       ├─ DNS -> 10.0.100.50   (endpoint ENI, PRIVATE IP)
       │
       └─ stays inside the VPC. No NAT, no IGW, no public IP.
```

AWS creates a **private hosted zone** for `logs.us-east-1.amazonaws.com` and attaches it to
your VPC. Now that name resolves to the ENI's private IPs for everything in the VPC.

The payoff: **your application needs zero changes.** Unmodified SDKs, boto3, the AWS CLI,
Terraform providers — everything keeps calling the normal hostname and silently gets the
private path. This is what lets a private subnet with **no NAT gateway at all** still use
AWS APIs.

### Side by side

|                          | `false`                              | `true`                    |
| ------------------------ | ------------------------------------ | ------------------------- |
| Normal hostname resolves to | AWS public IPs                    | endpoint private IPs      |
| Client code changes      | must set `--endpoint-url` everywhere | none                      |
| Traffic path             | NAT / IGW (public)                   | inside the VPC            |
| NAT data charges         | yes                                  | no                        |
| Works with no NAT        | no — times out                       | yes                       |
| You write Route53 records| yes, if you want it usable           | no                        |

### ⚠️ The one real danger of `true`

**It is VPC-wide, and it removes the public fallback.**

Once that private hosted zone is attached, *every* resource in the VPC resolves that hostname
to the endpoint. If the endpoint's security group doesn't allow a caller on 443, or its
endpoint policy denies the request, that caller **loses access to the service entirely** — it
cannot fall back to the public path, because DNS no longer returns public IPs.

That's a genuine outage mode, and it's why the default security group matters. If you narrow
the endpoint's inbound rules, you are also deciding who keeps access to that AWS service at
all.

Two smaller constraints:

- It requires `enable_dns_support` **and** `enable_dns_hostnames` on the VPC. (This module
  hardcodes both to `true`, so you're covered.)
- Only **one** endpoint per service per VPC can hold private DNS. A second one with the flag
  set will be rejected.

### The S3 special case worth knowing

S3 supports *both* endpoint types. If you create an S3 **interface** endpoint with private
DNS enabled while you also have a free S3 **gateway** endpoint, the interface endpoint
hijacks `s3.<region>.amazonaws.com` VPC-wide — so all your in-VPC S3 traffic now flows
through the **paid** interface endpoint and the free gateway endpoint goes unused.

The proper fix is an option called *private DNS only for inbound resolver endpoint*, which
keeps in-VPC traffic on the free gateway endpoint while letting on-premises traffic use the
interface endpoint. **This module does not expose that option**, so the practical guidance is:
use the **gateway** endpoint for S3 unless you specifically need on-premises access to S3.

---

## 8. Which services support which type

### Gateway — the complete list

- Amazon S3
- Amazon DynamoDB

That's it.

### Interface — almost everything else

Service names follow the pattern `com.amazonaws.<region>.<service>`. Commonly used ones:

| Service short name          | What it's for                                        |
| --------------------------- | ---------------------------------------------------- |
| `ecr.api` **and** `ecr.dkr` | Pulling container images — **you need both**         |
| `logs`                      | CloudWatch Logs (log drivers, application logging)   |
| `ssm`, `ssmmessages`, `ec2messages` | SSM Session Manager — **all three needed**   |
| `secretsmanager`            | Secrets Manager                                      |
| `kms`                       | KMS encrypt/decrypt                                  |
| `sts`                       | AssumeRole / caller identity                          |
| `sqs`, `sns`                | Messaging                                            |
| `monitoring`                | CloudWatch **metrics** (note: not called `cloudwatch`) |
| `events`                    | EventBridge                                          |
| `elasticloadbalancing`      | ELB API                                              |
| `execute-api`               | Calling private API Gateway APIs                     |

Notes that trip people up:

- **ECR needs two endpoints.** `ecr.api` handles authentication and the ECR control plane;
  `ecr.dkr` handles the actual Docker pull. One without the other fails.
- **ECR also needs S3.** Image *layers* live in S3, so container pulls need an S3 endpoint
  too — use the free **gateway** endpoint for that.
- **SSM Session Manager needs three:** `ssm`, `ssmmessages`, `ec2messages`.
- **CloudWatch metrics is `monitoring`,** not `cloudwatch`. Logs is `logs`.
- A few services don't follow the `com.amazonaws.` prefix at all — SageMaker uses
  `aws.sagemaker.<region>.notebook` and `aws.sagemaker.<region>.studio`. This module builds
  names as `com.amazonaws.<region>.<name>`, so those services aren't reachable through the
  `interface_endpoints` variable as written.

**A typical private-subnet ECS/EKS setup:**

```hcl
gateway_endpoints   = ["s3"]                                    # free — ECR layers live here
interface_endpoints = ["ecr.api", "ecr.dkr", "logs", "sts", "secretsmanager"]
```

---

## 9. Cost

### Gateway endpoints: free

No hourly charge, no data processing charge. There is no financial reason not to create an S3
gateway endpoint.

### Interface endpoints: two charges

1. **An hourly charge per endpoint, per AZ**, billed whenever the endpoint is provisioned —
   whether or not it carries traffic. Partial hours bill as full hours. In commercial
   regions this is on the order of **$0.01/hour per ENI**, so roughly **$7–8 per month per
   AZ per endpoint**. Rates vary by region — check the
   [PrivateLink pricing page](https://aws.amazon.com/privatelink/pricing/) for yours.
2. **A data processing charge per GB**, on all traffic regardless of direction:

   | Data processed per month | Price per GB |
   | ----------------------- | ------------ |
   | First 1 PB              | $0.01        |
   | Next 4 PB               | $0.006       |
   | Over 5 PB               | $0.004       |

### The multiplication trap

The hourly charge is **per endpoint per AZ**. Six interface endpoints across three AZs is
18 ENIs — around **$130/month before a single byte moves**.

So endpoints are not automatically cheaper than a NAT gateway. The rough decision:

- **High traffic volume** → endpoints win. Endpoint per-GB rates undercut NAT data
  processing, and you may drop the NAT entirely.
- **Low traffic, many services** → a NAT gateway may genuinely be cheaper than a dozen
  interface endpoints.
- **S3/DynamoDB** → always use the gateway endpoint. It's free and strictly better.
- **Compliance requires no public path** → endpoints, and cost isn't the deciding factor.

Only create the interface endpoints your workload actually calls. "Add them all just in
case" is a real and common source of surprise bills.

---

## 10. Endpoint policies

An **endpoint policy** is an IAM resource policy attached to the endpoint itself. It filters
what can be done *through that doorway*, independent of the caller's IAM permissions.

It's a powerful guardrail. The classic use is preventing data exfiltration to buckets you
don't own — even a caller with broad `s3:*` IAM rights can't reach an outside bucket if the
endpoint policy won't allow it:

```hcl
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::my-app-bucket", "arn:aws:s3:::my-app-bucket/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}
```

Both IAM **and** the endpoint policy must allow a request for it to succeed. If you leave the
policy off, AWS applies a default full-access policy and the endpoint filters nothing.

> **Careful:** an over-tight endpoint policy is a stealthy outage. Combined with private DNS,
> requests it denies have no public path to fall back to. Note that an S3 endpoint policy
> restricted to your own buckets will also break anything pulling from public AWS-owned
> buckets — including OS package repositories and, notably, ECR image layers.

---

## 11. Decision guide

**Do I need any endpoint at all?**
Do your private-subnet workloads call AWS APIs? If yes, and you'd rather not pay NAT data
charges or want to drop the NAT — yes.

**Which type?**

```
Is the service S3 or DynamoDB?
├─ YES ─▶ Do you need access from on-premises / a peered VPC / another Region?
│         ├─ NO  ─▶ GATEWAY endpoint. Free, simpler, no SG, no DNS concerns.
│         └─ YES ─▶ INTERFACE endpoint (gateway can't do this).
│                   Keep the gateway endpoint too for in-VPC traffic.
│
└─ NO ──▶ INTERFACE endpoint. It's the only option.
          └─ Then: is the traffic volume worth ~$7/mo/AZ + $0.01/GB
                   versus just routing through the NAT?
```

**Sensible starting point for a private-subnet VPC:**

```hcl
gateway_endpoints   = ["s3", "dynamodb"]   # free, always worth it
interface_endpoints = []                    # add only what you actually call
```

Then add interface endpoints as needs appear — driven by your workload, not by a checklist.

---

## 12. Common gotchas

**"I created the endpoint but nothing changed."**
Interface endpoint with `private_dns_enabled = false`. Your app is still calling the public
hostname and still going out the NAT. Set it to `true`.

**"Connections time out after I enabled the endpoint."**
The endpoint's security group doesn't allow inbound 443 from your callers. With private DNS
on, there's no public fallback — so it fails hard instead of degrading. Check the SG first.

**"My gateway endpoint doesn't work from on-premises."**
Expected and unfixable. Gateway endpoints only serve traffic originating in their own VPC.
Use an interface endpoint.

**"Container pulls still fail with ECR endpoints in place."**
You almost certainly need all three: `ecr.api`, `ecr.dkr`, **and** an S3 endpoint for the
image layers. Missing any one breaks the pull.

**"My bill went up."**
Interface endpoints charge per AZ per endpoint, always-on. Count your ENIs:
endpoints × AZs.

**"Cross-region S3 still goes through the NAT."**
Correct. Prefix lists are per-Region, so a gateway endpoint only captures same-Region S3.

**"Two endpoints for the same service failed to create."**
Only one endpoint per service per VPC can hold private DNS.

**"The endpoint failed to create in one of my AZs."**
Not every service is offered in every AZ, and the set differs by Region and even by account
(AZ names are shuffled per account). The module hands every private subnet to the endpoint,
so if a service is missing from one of your AZs the apply fails. Check the service's zones
with `aws ec2 describe-vpc-endpoint-services --service-names com.amazonaws.<region>.<name>`
and adjust `number_of_aws_az_use`.

**"I locked down instance egress and S3 broke."**
Gateway endpoints have no SG of their own, but your *instance's* SG needs egress to the
service prefix list on 443.

---

## 13. Troubleshooting checklist

When an endpoint isn't working, walk this in order:

1. **Is DNS resolving to a private IP?** From the instance:
   ```bash
   nslookup logs.us-east-1.amazonaws.com
   ```
   A `10.x` address means private DNS is working. A public address means
   `private_dns_enabled` is off, or the VPC lacks `enable_dns_support` /
   `enable_dns_hostnames`.

2. **Can you reach the ENI on 443?**
   ```bash
   nc -zv 10.0.100.50 443
   ```
   Failure points at the endpoint's security group or a NACL.

3. **Is the endpoint in the right AZ?** An ENI only exists in the subnets you selected. A
   workload in an AZ with no ENI has nothing local to talk to.

4. **For gateway endpoints, is the route present?** Check the route table for a
   `pl-…` → `vpce-…` entry. No route means the endpoint isn't associated with that table.

5. **For gateway endpoints, does the instance SG allow egress** to the prefix list on 443?

6. **Is an endpoint policy denying it?** Test by temporarily allowing full access. Remember
   both IAM and the endpoint policy must allow the call.

7. **Right service name?** `monitoring` not `cloudwatch`; `ecr.api` *and* `ecr.dkr`.

---

## 14. How this maps to this module

### Variables

| Variable                                 | What it controls                                                                 |
| ---------------------------------------- | -------------------------------------------------------------------------------- |
| `gateway_endpoints`                      | Short service names, e.g. `["s3", "dynamodb"]`. Expanded to `com.amazonaws.<region>.<name>`. |
| `interface_endpoints`                    | Short service names, e.g. `["ecr.api", "logs"]`. Same expansion. Requires `create_private_subnets = true`. |
| `interface_endpoint_private_dns_enabled` | Defaults to **`true`** — see [section 7](#7-dns--the-part-that-confuses-everyone). Applies to every interface endpoint. |
| `interface_endpoint_security_group_ids`  | Reuse existing SGs. If empty, the module creates one.                            |
| `interface_endpoint_sg_ingress` / `_egress` | Override the created SG's rules. Default ingress is TCP/443 from the VPC CIDR. |
| `gateway_endpoint_policies`              | `map(string)` of endpoint policy JSON, keyed by the same service short name.      |
| `interface_endpoint_policies`            | Same, for interface endpoints.                                                   |

### Behaviour baked into the module

- **Gateway endpoints attach to the private route tables only.** So
  `create_private_subnets = true` (or a `nat_type`) is required — there's a `precondition`
  that fails the plan with a clear message if you set `gateway_endpoints` without them,
  rather than silently building an endpoint that routes nothing.
- **Interface endpoints require private subnets.** A matching `precondition` fails the plan
  if `interface_endpoints` is set without `create_private_subnets = true`, for the reasons in
  [section 5](#5-where-do-endpoints-live-public-vs-private-subnets). There is no public
  subnet fallback.
- **One ENI per private subnet,** so one per AZ. Every private subnet is handed to every
  interface endpoint.
- **The security group is created only when needed** — that is, when you ask for interface
  endpoints *and* don't supply your own SG ids.
- **Private DNS is on by default,** which is the setting that makes an endpoint actually get
  used. It is one setting for all interface endpoints, not per service.
- **`enable_dns_support` and `enable_dns_hostnames` are hardcoded `true`** on the VPC, which
  private DNS requires.

Not covered: PrivateLink endpoints to services published by another account or a partner
(`com.amazonaws.vpce.<region>.vpce-svc-…`). This module only builds endpoints to AWS's own
services.

### A complete example

```hcl
module "vpc" {
  source     = "./vpc"
  name       = "app-vpc"
  cidr_block = "10.0.0.0/16"

  create_private_subnets = true
  nat_type               = "gateway"

  # Free — always worth having with private subnets.
  gateway_endpoints = ["s3", "dynamodb"]

  # Only what this workload actually calls.
  interface_endpoints = ["ecr.api", "ecr.dkr", "logs", "sts"]

  # Optional: restrict which apps may use the endpoints.
  interface_endpoint_sg_ingress = [
    {
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]

  providers = {
    aws = aws
  }
}
```

See [EXAMPLE.md](EXAMPLE.md) for more usage patterns and [README.md](README.md) for the full
generated input/output reference.

---

## Further reading

- [Gateway endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html)
- [Access an AWS service using an interface VPC endpoint](https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html)
- [AWS PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/)
- [AWS PrivateLink for Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/privatelink-interface-endpoints.html)
- [AWS-managed prefix lists](https://docs.aws.amazon.com/vpc/latest/userguide/working-with-aws-managed-prefix-lists.html)
