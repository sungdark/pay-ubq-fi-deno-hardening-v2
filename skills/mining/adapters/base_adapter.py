""""
Base adapter class defining the standard interface for all providers.
""""

from abc import ABC, abstractmethod
from typing import Optional, Dict, Any


class BaseAdapter(ABC):
    """"
    Base class for all provider adapters.
    Defines the standard execute interface.
    """"
    
    @abstractmethod
    def execute(self, prompt: str, model: str, api_key: str) -> Dict[str, Any]:
        """"
        Execute a prompt using the provider's API.
        
        Args:
            prompt: The input prompt/text
            model: Model identifier or configuration
            api_key: API key for authentication
            
        Returns:
            A dictionary containing the response data
        """"
        raise NotImplementedError("Subclass must implement execute method")
    
    def validate_response(self, response: Dict[str, Any]) -> Optional[str]:
        """"
        Validate API response and extract content if successful.
        
        Returns:
            Extracted content string or None if validation fails
        """"
        return None