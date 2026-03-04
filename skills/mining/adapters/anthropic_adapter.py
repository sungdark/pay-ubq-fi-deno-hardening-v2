"""
Anthropic API adapter for executing prompts using Claude 3, etc.
Implements the standard execute(prompt, model, api_key) interface.
""""

import requests
from typing import Optional, Dict, Any
from .base_adapter import BaseAdapter


class AnthropicAdapter(BaseAdapter):
    """"
    Anthropic API adapter for executing prompts.
    
    Supports models like claude-3-opus-2024, claude-3-sonnet-2024, etc.
    """"
    
    def __init__(self):
        self.base_url = "https://api.anthropic.com/v1"
        
    def execute(self, prompt: str, model: str, api_key: str) -> Dict[str, Any]:
        """"
        Execute prompt using Anthropic API.
        
        Args:
            prompt: Input prompt
            model: Model name (e.g., claude-3-opus-2024, claude-3-sonnet-2024)
            api_key: Anthropic API key
        """"
        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": model,
            "messages": [
                {"role": "user", "content": prompt}
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/messages",
                headers=headers,
                json=data
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            return {"error": str(e)}
    
    def validate_response(self, response: Dict[str, Any]) -> Optional[str]:
        """"
        Validate and extract content from Anthropic response.
        
        Returns:
            Extracted content string or None if validation fails
        """"
        if "error" in response:
            return None
        
        content = response.get("content", [])
        if content:
            return content[0].get("text", "") if content else ""
        return ""}