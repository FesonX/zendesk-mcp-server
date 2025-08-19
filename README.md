# Zendesk MCP Server

![ci](https://github.com/reminia/zendesk-mcp-server/actions/workflows/ci.yml/badge.svg)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A Model Context Protocol server for Zendesk.

This server provides a comprehensive integration with Zendesk. It offers:

- Tools for retrieving and managing Zendesk tickets and comments
- Specialized prompts for ticket analysis and response drafting
- Intelligent search-based access to Zendesk Help Center articles
- Efficient knowledge base tools with caching and pagination

![demo](https://res.cloudinary.com/leecy-me/image/upload/v1736410626/open/zendesk_yunczu.gif)

## Setup

- build: `uv venv && uv pip install -e .` or `uv build` in short.
- setup zendesk credentials in `.env` file, refer to [.env.example](.env.example).
- configure in Claude desktop:

```json
{
  "mcpServers": {
      "zendesk": {
          "command": "uv",
          "args": [
              "--directory",
              "/path/to/zendesk-mcp-server",
              "run",
              "zendesk"
          ]
      }
  }
}
```

## Resources

- zendesk://knowledge-base - Returns metadata about the help center (sections list). Use the search tools below to find specific articles.

## Prompts

### analyze-ticket

Analyze a Zendesk ticket and provide a detailed analysis of the ticket.

### draft-ticket-respons

Draft a response to a Zendesk ticket.

## Tools

### get_ticket

Retrieve a Zendesk ticket by its ID

- Input:
  - `ticket_id` (integer): The ID of the ticket to retrieve

### get_ticket_comments

Retrieve all comments for a Zendesk ticket by its ID

- Input:
  - `ticket_id` (integer): The ID of the ticket to get comments for

### create_ticket_comment

Create a new comment on an existing Zendesk ticket

- Input:
  - `ticket_id` (integer): The ID of the ticket to comment on
  - `comment` (string): The comment text/content to add
  - `public` (boolean, optional): Whether the comment should be public (defaults to true)

### search_kb_articles

Search Zendesk Help Center articles by query

- Input:
  - `query` (string): Search query to find relevant articles
  - `limit` (integer, optional): Maximum number of articles to return (defaults to 10)

### get_kb_article

Get a specific Zendesk Help Center article by ID

- Input:
  - `article_id` (integer): The ID of the article to retrieve

### list_kb_sections

List all Zendesk Help Center sections

- Input: None

### get_section_articles

Get articles from a specific Zendesk Help Center section

- Input:
  - `section_id` (integer): The ID of the section
  - `limit` (integer, optional): Maximum number of articles to return (defaults to 20)
