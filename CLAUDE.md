# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Model Context Protocol (MCP) server that provides AI assistants with access to Zendesk Support tickets and Help Center articles. The server exposes tools, prompts, and resources through the MCP protocol.

## Build and Development Commands

The project uses `uv` for Python package management:

- **Install dependencies**: `uv venv && uv pip install -e .`
- **Build package**: `uv build`
- **Run server**: `uv run zendesk` (requires `.env` configuration)

## Configuration

The server requires Zendesk credentials in a `.env` file:
```
ZENDESK_SUBDOMAIN=xxx
ZENDESK_EMAIL=xxx
ZENDESK_API_KEY=xxx
```

See `.env.example` for the template.

## Architecture

### Three-Layer Structure

1. **server.py** - Main MCP server implementation
   - Defines MCP handlers for tools, prompts, and resources
   - Routes requests to the Zendesk client
   - Implements caching strategy with TTL-based decorators

2. **zendesk_client.py** - Zendesk API wrapper
   - Thin wrapper around the `zenpy` library
   - Handles all direct communication with Zendesk API
   - Returns dictionaries for serialization

3. **__init__.py** - Entry point
   - Provides the `main()` function that starts the asyncio server

### MCP Protocol Implementation

The server implements three MCP primitives:

- **Tools**: Direct API operations (get_ticket, search_kb_articles, etc.)
- **Prompts**: Templated workflows (analyze-ticket, draft-ticket-response)
- **Resources**: URI-based access to knowledge base metadata (zendesk://knowledge-base)

### Caching Strategy

Knowledge base operations use TTL caching to reduce API calls:
- Sections list: 2 hours (`@ttl_cache(ttl=7200)`)
- Individual articles: 1 hour (`@ttl_cache(ttl=3600)`)
- Search results: 15 minutes (`@ttl_cache(ttl=900)`)

Ticket operations are not cached as they need real-time data.

### Search-First Knowledge Base Design

The knowledge base resource returns only metadata (section list). Users are directed to use `search_kb_articles` tool for article discovery. This prevents loading excessive content into context and improves performance.

## Key Design Patterns

- All Zendesk client methods return dictionaries (not zenpy objects) for JSON serialization
- Long article bodies are truncated to 1000 characters in list views; full content available via `get_kb_article`
- Error handling returns user-friendly error messages through MCP TextContent
- Logging uses standard Python logging with INFO level for operational visibility

### Attachment Handling

The server supports ticket attachments (images, PDFs, documents):

- **Metadata in comments**: Attachment info (ID, filename, type, size, URL) is included in `get_ticket_comments` responses
- **On-demand fetching**: Use `get_attachment` tool to download specific attachments
- **Native image support**: Images returned as MCP `ImageContent` for direct viewing by multimodal AI
- **Non-image files**: PDFs/documents returned as base64-encoded data in JSON
- **Inline images**: Optional `include_inline_images` parameter to fetch inline attachments

**Workflow:**

**Option 1: Manual (token-efficient)**
1. Call `get_ticket_comments(ticket_id)` to see attachment metadata
2. Identify relevant attachments (check `is_image` flag and `content_type`)
3. Call `get_attachment(attachment_id)` to view/download specific files

**Option 2: Automatic inline images**
1. Call `get_ticket_comments(ticket_id, include_inline_images=true)`
2. All image attachments are automatically fetched and returned as `ImageContent`
3. Images display natively in multimodal AI clients

**Token efficiency**:
- Manual mode: Only download what you need (~99% savings for large tickets)
- Automatic mode: Best for tickets with few images (<10) where visual context is essential
