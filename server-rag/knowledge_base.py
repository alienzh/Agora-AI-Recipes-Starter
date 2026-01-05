"""
Knowledge Base Management Module

This module provides functionality to manage and query the knowledge base.
You can extend this to use vector databases, embedding models, or external knowledge sources.
"""

import json
import os
from typing import List, Dict, Optional
import logging

logger = logging.getLogger(__name__)


class KnowledgeBase:
    """
    Simple in-memory knowledge base manager.
    
    For production use, consider replacing with:
    - Vector databases (Chroma, Pinecone, Weaviate)
    - Embedding models for semantic search
    - External knowledge sources (databases, APIs)
    """
    
    def __init__(self, knowledge_dict: Optional[Dict[str, List[str]]] = None):
        """
        Initialize knowledge base.
        
        Args:
            knowledge_dict: Dictionary of category -> list of documents
        """
        self.knowledge = knowledge_dict or {}
    
    def load_from_file(self, file_path: str):
        """
        Load knowledge base from JSON file.
        
        Args:
            file_path: Path to JSON file containing knowledge base
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                self.knowledge = json.load(f)
            logger.info(f"Loaded knowledge base from {file_path}")
        except FileNotFoundError:
            logger.warning(f"Knowledge base file not found: {file_path}, using empty knowledge base")
            self.knowledge = {}
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in knowledge base file: {e}")
            self.knowledge = {}
    
    def add_document(self, category: str, document: str):
        """
        Add a document to the knowledge base.
        
        Args:
            category: Category name
            document: Document text to add
        """
        if category not in self.knowledge:
            self.knowledge[category] = []
        self.knowledge[category].append(document)
        logger.debug(f"Added document to category '{category}'")
    
    def search(self, query: str, top_k: int = 3) -> List[str]:
        """
        Search the knowledge base for relevant documents.
        
        Args:
            query: Search query
            top_k: Number of top results to return
        
        Returns:
            List of relevant document texts
        """
        query_lower = query.lower()
        query_words = set(query_lower.split())
        
        scored_docs = []
        
        # Simple keyword-based scoring
        for category, docs in self.knowledge.items():
            for doc in docs:
                doc_lower = doc.lower()
                # Count matching keywords
                score = sum(1 for word in query_words if word in doc_lower)
                if score > 0:
                    scored_docs.append((score, doc))
        
        # Sort by score (descending) and return top_k
        scored_docs.sort(key=lambda x: x[0], reverse=True)
        results = [doc for _, doc in scored_docs[:top_k]]
        
        # If no matches found, return default documents
        if not results:
            results = self.knowledge.get("default", [])[:top_k]
        
        return results
    
    def get_all_documents(self) -> List[str]:
        """
        Get all documents from the knowledge base.
        
        Returns:
            List of all document texts
        """
        all_docs = []
        for docs in self.knowledge.values():
            all_docs.extend(docs)
        return all_docs


# Global knowledge base instance
_kb_instance: Optional[KnowledgeBase] = None


def get_knowledge_base() -> KnowledgeBase:
    """
    Get the global knowledge base instance.
    
    Returns:
        KnowledgeBase instance
    """
    global _kb_instance
    if _kb_instance is None:
        _kb_instance = KnowledgeBase()
        # Try to load from file if exists
        kb_file = os.path.join(os.path.dirname(__file__), "knowledge_base.json")
        if os.path.exists(kb_file):
            _kb_instance.load_from_file(kb_file)
    return _kb_instance

