"""
Knowledge Base Management Module

This module provides functionality to manage and query the knowledge base.
You can extend this to use vector databases, embedding models, or external knowledge sources.
"""

import json
import os
import re
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
    
    def _normalize_text(self, text: str) -> str:
        """
        Normalize text for better matching: remove punctuation, convert to lowercase.
        
        Args:
            text: Input text
        
        Returns:
            Normalized text
        """
        # Remove punctuation and special characters, keep Chinese, English, and numbers
        text = re.sub(r'[^\w\s\u4e00-\u9fff]', '', text)
        # Convert to lowercase
        text = text.lower()
        return text
    
    def _extract_keywords(self, text: str) -> set:
        """
        Extract keywords from text for matching.
        Handles both Chinese and English words, preserving English words as-is.
        
        Args:
            text: Input text
        
        Returns:
            Set of keywords
        """
        keywords = set()
        
        # First, extract English words (alphanumeric sequences)
        english_words = re.findall(r'[a-zA-Z]+', text.lower())
        keywords.update(english_words)
        
        # Then, normalize and extract Chinese words and other tokens
        normalized = self._normalize_text(text)
        # Split by whitespace and filter out empty strings
        all_words = set(word for word in normalized.split() if word)
        keywords.update(all_words)
        
        # Also add the original text as a whole for substring matching
        # This helps with queries like "什么是 Agora？" where "Agora" should match
        normalized_whole = self._normalize_text(text)
        if normalized_whole:
            keywords.add(normalized_whole)
        
        return keywords
    
    def search(self, query: str, top_k: int = 3) -> List[str]:
        """
        Search the knowledge base for relevant documents.
        
        Args:
            query: Search query
            top_k: Number of top results to return
        
        Returns:
            List of relevant document texts
        """
        query_keywords = self._extract_keywords(query)
        logger.debug(f"🔍 Extracted keywords from query: {query_keywords}")
        
        if not query_keywords:
            logger.warning("⚠️ No keywords extracted from query")
            return self.knowledge.get("default", [])[:top_k]
        
        scored_docs = []
        
        # Simple keyword-based scoring
        for category, docs in self.knowledge.items():
            # Skip default category during search, only use it as fallback
            if category == "default":
                continue
                
            for doc in docs:
                doc_normalized = self._normalize_text(doc)
                # Count matching keywords with improved matching
                score = 0
                matched_keywords = []
                for keyword in query_keywords:
                    # For English words, use word boundary matching for better accuracy
                    if re.match(r'^[a-zA-Z]+$', keyword):
                        # English word: use word boundary matching
                        if re.search(r'\b' + re.escape(keyword) + r'\b', doc_normalized, re.IGNORECASE):
                            score += 2  # Higher score for exact word match
                            matched_keywords.append(keyword)
                        elif keyword in doc_normalized:
                            score += 1  # Lower score for substring match
                            matched_keywords.append(keyword)
                    else:
                        # Chinese or mixed: use substring matching
                        if keyword in doc_normalized:
                            score += 1
                            matched_keywords.append(keyword)
                
                if score > 0:
                    scored_docs.append((score, doc, category))
                    logger.debug(f"🎯 Knowledge Base Match: category='{category}', score={score}, matched_keywords={matched_keywords}, doc_preview='{doc[:50]}...'")
        
        # Sort by score (descending) and return top_k
        scored_docs.sort(key=lambda x: x[0], reverse=True)
        results = [doc for score, doc, category in scored_docs[:top_k]]
        
        logger.info(f"📚 Search results: found {len(results)} documents from {len(set(cat for _, _, cat in scored_docs[:top_k]))} categories")
        
        # If no matches found, return default documents
        if not results:
            logger.warning(f"⚠️ No matches found for query, using default documents")
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

