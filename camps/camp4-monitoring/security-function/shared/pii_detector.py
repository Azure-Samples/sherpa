"""
PII Detection Module using Azure AI Language

Wraps Azure AI Language's PII detection service to identify and redact
personally identifiable information from MCP responses.
"""

import os
import logging
from typing import NamedTuple

from azure.ai.textanalytics import TextAnalyticsClient
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential

logger = logging.getLogger(__name__)


class PIIResult(NamedTuple):
    """Result of PII detection and redaction."""
    redacted_text: str
    entities_found: list[dict]
    error: str | None


def get_client() -> TextAnalyticsClient | None:
    """
    Get Azure AI Language client with managed identity authentication.
    
    Returns:
        TextAnalyticsClient or None if configuration is missing
    """
    endpoint = os.environ.get("AI_SERVICES_ENDPOINT")
    if not endpoint:
        logger.warning("AI_SERVICES_ENDPOINT not configured")
        return None
    
    # Use managed identity in Azure, DefaultAzureCredential for local dev
    client_id = os.environ.get("AZURE_CLIENT_ID")
    if client_id:
        credential = ManagedIdentityCredential(client_id=client_id)
    else:
        credential = DefaultAzureCredential()
    
    return TextAnalyticsClient(endpoint=endpoint, credential=credential)


def detect_and_redact_pii(text: str) -> PIIResult:
    """
    Detect and redact PII from text using Azure AI Language.
    
    Args:
        text: The text to scan for PII
        
    Returns:
        PIIResult with redacted text and list of entities found
    """
    if not text or not text.strip():
        return PIIResult(redacted_text=text, entities_found=[], error=None)
    
    client = get_client()
    if not client:
        return PIIResult(
            redacted_text=text,
            entities_found=[],
            error="PII detection service not configured"
        )
    
    try:
        # Azure AI Language has a character limit per document
        # Split large texts if needed
        max_chars = 5000
        if len(text) > max_chars:
            # Process in chunks, preserving structure
            chunks = [text[i:i+max_chars] for i in range(0, len(text), max_chars)]
            all_entities = []
            redacted_chunks = []
            
            for chunk in chunks:
                result = client.recognize_pii_entities([chunk])[0]
                if result.is_error:
                    logger.error(f"PII detection error: {result.error}")
                    redacted_chunks.append(chunk)
                    continue
                
                # Redact entities in reverse order to preserve positions
                redacted = chunk
                for entity in sorted(result.entities, key=lambda e: e.offset, reverse=True):
                    redaction = f"[REDACTED-{entity.category}]"
                    redacted = redacted[:entity.offset] + redaction + redacted[entity.offset + entity.length:]
                    all_entities.append({
                        "category": entity.category,
                        "subcategory": entity.subcategory,
                        "confidence": entity.confidence_score,
                        "text_length": entity.length
                    })
                redacted_chunks.append(redacted)
            
            return PIIResult(
                redacted_text="".join(redacted_chunks),
                entities_found=all_entities,
                error=None
            )
        
        # Process single document
        result = client.recognize_pii_entities([text])[0]
        
        if result.is_error:
            logger.error(f"PII detection error: {result.error}")
            return PIIResult(
                redacted_text=text,
                entities_found=[],
                error=str(result.error)
            )
        
        # Redact entities in reverse order to preserve positions
        redacted = text
        entities_found = []
        
        for entity in sorted(result.entities, key=lambda e: e.offset, reverse=True):
            redaction = f"[REDACTED-{entity.category}]"
            redacted = redacted[:entity.offset] + redaction + redacted[entity.offset + entity.length:]
            entities_found.append({
                "category": entity.category,
                "subcategory": entity.subcategory,
                "confidence": entity.confidence_score,
                "text_length": entity.length
            })
        
        return PIIResult(
            redacted_text=redacted,
            entities_found=entities_found,
            error=None
        )
        
    except Exception as e:
        logger.exception("PII detection failed")
        return PIIResult(
            redacted_text=text,
            entities_found=[],
            error=str(e)
        )
