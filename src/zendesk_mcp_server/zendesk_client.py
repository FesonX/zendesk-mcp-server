from typing import Dict, Any, List
import logging
import base64

from zenpy import Zenpy
from zenpy.lib.api_objects import Comment

logger = logging.getLogger(__name__)


class ZendeskClient:
    def __init__(self, subdomain: str, email: str, token: str, timeout: int = 30):
        """
        Initialize the Zendesk client using zenpy lib.
        """
        self.client = Zenpy(
            subdomain=subdomain,
            email=email,
            token=token,
            timeout=timeout
        )

    def get_ticket(self, ticket_id: int) -> Dict[str, Any]:
        """
        Query a ticket by its ID
        """
        try:
            ticket = self.client.tickets(id=ticket_id)
            return {
                'id': ticket.id,
                'subject': ticket.subject,
                'description': ticket.description,
                'status': ticket.status,
                'priority': ticket.priority,
                'created_at': str(ticket.created_at),
                'updated_at': str(ticket.updated_at),
                'requester_id': ticket.requester_id,
                'assignee_id': ticket.assignee_id,
                'organization_id': ticket.organization_id
            }
        except Exception as e:
            raise Exception(f"Failed to get ticket {ticket_id}: {str(e)}")

    def get_ticket_comments(self, ticket_id: int, include_inline_images: bool = False) -> List[Dict[str, Any]]:
        """
        Get all comments for a specific ticket.

        Args:
            ticket_id: ID of the ticket
            include_inline_images: Whether to include inline image attachments (default: False)
        """
        try:
            # Fetch comments with optional inline images
            if include_inline_images:
                comments = self.client.tickets.comments(
                    ticket=ticket_id,
                    include_inline_images=True
                )
            else:
                comments = self.client.tickets.comments(ticket=ticket_id)

            return [{
                'id': comment.id,
                'author_id': comment.author_id,
                'body': comment.body,
                'html_body': comment.html_body,
                'public': comment.public,
                'created_at': str(comment.created_at),
                'attachments': [
                    {
                        'id': att.id,
                        'file_name': att.file_name,
                        'content_type': att.content_type,
                        'content_url': att.content_url,
                        'size': att.size,
                        'is_image': att.content_type.startswith('image/') if att.content_type else False
                    }
                    for att in (comment.attachments or [])
                ] if comment.attachments else []
            } for comment in comments]
        except Exception as e:
            raise Exception(f"Failed to get comments for ticket {ticket_id}: {str(e)}")

    def post_comment(self, ticket_id: int, comment: str, public: bool = True) -> str:
        """
        Post a comment to an existing ticket.
        """
        try:
            ticket = self.client.tickets(id=ticket_id)
            ticket.comment = Comment(
                html_body=comment,
                public=public
            )
            self.client.tickets.update(ticket)
            return comment
        except Exception as e:
            raise Exception(f"Failed to post comment on ticket {ticket_id}: {str(e)}")

    def search_articles(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Search help center articles by query.
        """
        try:
            results = self.client.help_center.articles.search(query=query)
            articles = []
            for i, article in enumerate(results):
                if i >= limit:
                    break
                articles.append({
                    'id': article.id,
                    'title': article.title,
                    'body': article.body[:1000] if len(article.body) > 1000 else article.body,
                    'section_id': article.section_id,
                    'updated_at': str(article.updated_at),
                    'url': article.html_url
                })
            logger.info(f"Found {len(articles)} articles for query: {query}")
            return articles
        except Exception as e:
            logger.error(f"Failed to search articles: {str(e)}")
            raise Exception(f"Failed to search articles: {str(e)}")

    def get_article(self, article_id: int) -> Dict[str, Any]:
        """
        Get a specific help center article by ID.
        """
        try:
            article = self.client.help_center.articles(id=article_id)
            return {
                'id': article.id,
                'title': article.title,
                'body': article.body,
                'section_id': article.section_id,
                'author_id': article.author_id,
                'updated_at': str(article.updated_at),
                'url': article.html_url,
                'vote_sum': article.vote_sum,
                'vote_count': article.vote_count
            }
        except Exception as e:
            logger.error(f"Failed to get article {article_id}: {str(e)}")
            raise Exception(f"Failed to get article {article_id}: {str(e)}")

    def list_sections(self) -> List[Dict[str, Any]]:
        """
        List all help center sections (lightweight, no articles).
        """
        try:
            sections = self.client.help_center.sections()
            return [{
                'id': section.id,
                'name': section.name,
                'description': section.description,
                'category_id': section.category_id,
                'position': section.position,
                'updated_at': str(section.updated_at)
            } for section in sections]
        except Exception as e:
            logger.error(f"Failed to list sections: {str(e)}")
            raise Exception(f"Failed to list sections: {str(e)}")

    def get_section_articles(self, section_id: int, limit: int = 20) -> List[Dict[str, Any]]:
        """
        Get articles for a specific section.
        """
        try:
            articles = self.client.help_center.sections.articles(section_id=section_id)
            result = []
            for i, article in enumerate(articles):
                if i >= limit:
                    break
                result.append({
                    'id': article.id,
                    'title': article.title,
                    'body': article.body[:1000] if len(article.body) > 1000 else article.body,
                    'updated_at': str(article.updated_at),
                    'url': article.html_url
                })
            logger.info(f"Found {len(result)} articles in section {section_id}")
            return result
        except Exception as e:
            logger.error(f"Failed to get section articles: {str(e)}")
            raise Exception(f"Failed to get section articles: {str(e)}")

    def get_attachment(self, attachment_id: int | str) -> Dict[str, Any]:
        """
        Download and return an attachment by ID.

        Args:
            attachment_id: The ID of the attachment to download

        Returns:
            Dictionary with attachment metadata and base64-encoded data
        """
        try:
            # Convert to int if string
            attachment_id = int(attachment_id) if isinstance(attachment_id, str) else attachment_id

            # Get attachment metadata first
            attachment = self.client.attachments(id=attachment_id)

            # Download attachment content to BytesIO
            content_stream = self.client.attachments.download(attachment_id)

            # Encode as base64
            base64_data = base64.b64encode(content_stream.getvalue()).decode('utf-8')

            logger.info(f"Downloaded attachment {attachment_id}: {attachment.file_name} ({attachment.size} bytes)")
            return {
                'id': attachment.id,
                'file_name': attachment.file_name,
                'content_type': attachment.content_type,
                'size': attachment.size,
                'data': base64_data
            }
        except Exception as e:
            logger.error(f"Failed to download attachment {attachment_id}: {str(e)}")
            raise Exception(f"Failed to download attachment {attachment_id}: {str(e)}")
