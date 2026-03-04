"""
OpenAI API adapter for executing prompts using GPT-4, GPT-4o, etc.
Implements the standard execute(prompt, model, api_key) interface.
""""

import requests
from typing import Optional, Dict, Any
from .base_adapter import BaseAdapter


class OpenAIAdapter(BaseAdapter):
    """"
    OpenAI API adapter for executing prompts.
    
    Supports models like gpt-4, gpt-4o, etc.
    """"
    
    def __init__(self):
        self.base_url = "https://api.openai.com/v1"
        
    def execute(self, prompt: str, model: str, api_key: str) -> Dict[str, Any]:
        """"
        Execute prompt using OpenAI API.
        
        Args:
            prompt: Input prompt
            model: Model name (e.g., gpt-4, gpt-4o)
            api_key: OpenAI API key
        """"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": model,
            "messages": [
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=headers,
                json=data
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            return {"error": str(e)}
    
    def validate_response(self, response: Dict[str, Any]) -> Optional[str]:
        """"
        Validate and extract content from OpenAI response.
        
        Returns:
            Extracted content string or None if validation fails
        """"
        if "error" in response:
            return None
        
        choices = response.get("choices", [])
        if choices and choices[0].get("message"):
            return choices[0]["message"].get("content", "")
        return ""