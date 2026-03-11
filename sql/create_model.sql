CREATE DATABASE ragtdb
GO

ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

EXEC sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE;

SELECT
AI_GENERATE_EMBEDDINGS(
 'SQL Server AI demo running in AKS'
 USE MODEL ollama_embeddings
);


DROP EXTERNAL MODEL IF EXISTS ollama_embeddings;
GO

CREATE EXTERNAL MODEL ollama_embeddings
WITH (
    LOCATION = 'https://127.0.0.1:8443/v1/embeddings',
    API_FORMAT = 'OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text'
);
GO

