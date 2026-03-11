CREATE TABLE DemoDocuments
(
    Id INT IDENTITY PRIMARY KEY,
    TextContent NVARCHAR(500),
    Embedding VECTOR(768)
);
GO

select * from DemoDocuments
INSERT INTO DemoDocuments (TextContent, Embedding)
VALUES
(
 'SQL Server is a relational database developed by Microsoft',
 AI_GENERATE_EMBEDDINGS(
   'SQL Server is a relational database developed by Microsoft'
   USE MODEL ollama_embeddings
 )
),
(
 'Kubernetes is a container orchestration platform',
 AI_GENERATE_EMBEDDINGS(
   'Kubernetes is a container orchestration platform'
   USE MODEL ollama_embeddings
 )
),
(
 'Machine learning enables computers to learn from data',
 AI_GENERATE_EMBEDDINGS(
   'Machine learning enables computers to learn from data'
   USE MODEL ollama_embeddings
 )
),
(
 'Vector search allows semantic similarity queries',
 AI_GENERATE_EMBEDDINGS(
   'Vector search allows semantic similarity queries'
   USE MODEL ollama_embeddings
 )
),
(
 'Artificial intelligence is transforming modern applications',
 AI_GENERATE_EMBEDDINGS(
   'Artificial intelligence is transforming modern applications'
   USE MODEL ollama_embeddings
 )
);
GO


SELECT 
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'DemoDocuments';



CREATE VECTOR INDEX idx_demo_embeddings
ON DemoDocuments(Embedding)
WITH (metric = 'cosine');



DECLARE @queryVector VECTOR(768);

SET @queryVector =
AI_GENERATE_EMBEDDINGS(
 'AI and machine learning technologies'
 USE MODEL ollama_embeddings
);

SELECT TOP 3
    Id,
    TextContent,
    1 - VECTOR_DISTANCE('cosine', Embedding, @queryVector) AS Similarity
FROM DemoDocuments
ORDER BY Similarity DESC;