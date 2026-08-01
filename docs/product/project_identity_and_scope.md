---
title: "Sanad Agent Identity and Scope"
description: "Public identity, open-source scope, hosted-service boundary, and project naming."
---

# Sanad Agent Identity and Scope

## Identity

**Sanad Agent** is an independent MIT-licensed open-source AI agent project. It
is created by Ahmed Attia and developed under EastStar AI, an independent AI
studio.

The project includes the native Dart agent, Flutter client, public protocols,
documentation, tests, and release tooling in this repository.

## Open-source scope

The repository contains:

- the Dart command-line and background agent;
- the Flutter client for desktop, mobile, and web;
- local execution, workspaces, sessions, tools, MCP, skills, permissions,
  providers, memory, and scheduling;
- public local and hosted-service interface contracts;
- development, build, test, and release tooling.

The agent and desktop client can run locally without EastStar AI hosted
services. A supported local model provider can keep model requests on the same
computer.

## Optional hosted services

EastStar AI provides optional hosted identity, device inventory, Portal, and
relay services for:

- signing in from multiple clients;
- pairing computers and servers;
- selecting and controlling remote agents;
- accessing a remote device from mobile or web.

These services do not replace the agent. Workspace execution and local state
remain owned by the device running Sanad Agent. The hosted service boundary is
documented in [Hosted Services Boundary](../technical/hosted_services_boundary.md).

The server implementation and production infrastructure for the hosted
services are not included in this repository. Access to their source is not
required to build Sanad Agent or use its local mode.

## Naming

The public project name is **Sanad Agent**. The executable command is `sanad`,
and the interface is referred to as **Sanad Client** when the distinction
between the two components matters.

Older unpublished development names do not define public compatibility or
migration requirements. Public releases, package metadata, visible interface
text, and current documentation use the Sanad identity.

## Ownership and governance

Ahmed Attia holds the copyright and is the initial merge and release
authority. EastStar AI is the independent studio identity under which the
project is developed. Contribution and governance policies can evolve
transparently as the maintainer and contributor community grows.
