# SQL Server 2025 + Ollama + Caddy Container in AKS

This guide demonstrates how to deploy semantic vector search inside SQL Server running on Azure Kubernetes Service (AKS) using local embedding models served via Ollama.  

The architecture enables AI-powered similarity search directly inside SQL Server using:  
- SQL Server 2025 Vector data type  
- Ollama embedding models  
- Kubernetes container orchestration  
- Secure HTTPS communication for SQL Server AI integration


This approach allows running AI inference locally within the Kubernetes cluster, avoiding external AI service dependencies.

## Architecture Overview

The solution uses a Sidecar Pattern within a single Kubernetes Pod to orchestrate communication between the database and the AI model over localhost.

<img width="1536" height="1024" alt="vs_aks" src="https://github.com/user-attachments/assets/d2601f20-5ba3-49ea-957e-e558ed4a1af7" />

Multi-Container Pod Design
- SQL Server 2025 (mssql-server:2025-latest): Acts as the primary vector store using the new VECTOR data type.  
- Ollama : The local inference engine hosting the nomic-embed-text model.  
- Caddy : A lightweight HTTPS proxy. SQL Server 2025 requires an encrypted endpoint to call external models; Caddy provides this TLS layer for Ollama’s default HTTP API.

## Deployment Steps
### Phase 1: Security & Certificates

<b>1. Generate TLS Certificates</b>  

SQL Server requires an encrypted connection to communicate with the model endpoint. We use a self-signed certificate stored in a Kubernetes Secret.

```
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout localhost.key -out localhost.crt -subj "/CN=localhost" -addext "subjectAltName = DNS:localhost,IP:127.0.0.1,IP:::1"
```

<b>2. Create the K8s Secret</b>   

```
kubectl create secret generic ollama-tls --from-file=localhost.crt=./localhost.crt --from-file=localhost.key=./localhost.key
```
### Phase 2: Infrastructure Configuration

We need persistent storage for the database files and the AI models to ensure they aren't lost if the Pod restarts.

<b>PVC and Storage Class (pvc.yaml) </b>  

We use Azure Disk (Standard_LRS) to provide persistent volumes for both SQL data and the Ollama model library.  
- SQL Data: (Adjust the disk size based on your dataset).
- Ollama Models: Persistent storage prevents re-downloading large models on every restart.
  
<b> Caddy Configuration (caddy-config.yaml) </b>  

The Caddyfile tells Caddy to listen on port 8443 using our generated certificates and reverse-proxy all traffic to Ollama's default port (11434).

### Phase 3: Deploying the AI-SQL Pod

The ai-sql-pod.yaml brings everything together. 

Key Container Roles:  
- sqlserver: Includes a custom command block that injects the localhost.crt into the Linux and SQL Server trust stores.  
  This is critical; otherwise, SQL Server will reject the connection to the Caddy proxy due to an untrusted certificate.
- ollama: Runs the standard Ollama image. It is ready to serve requests as soon as a model is pulled.
- caddy: Uses the caddy-config ConfigMap to secure the internal traffic.

```
kubectl apply -f pvc.yaml
kubectl apply -f caddy-config.yaml
kubectl apply -f ai-sql-pod.yaml
```

### Phase 4: Database Implementation

<b>1. Enable the feature and Register the Local Model (create_model.sql)</b>  

```
CREATE DATABASE ragtdb
GO

ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;
GO

EXEC sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE;
```
This points SQL Server to the Caddy proxy address.
```
CREATE EXTERNAL MODEL ollama_embeddings
WITH (
    LOCATION = 'https://127.0.0.1:8443/v1/embeddings',
    API_FORMAT = 'OpenAI',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text'
);
```
<b>2. Table Creation and Vector Search (vector_search.sql)</b>  

We use the new VECTOR(768) type. The 768 dimension matches the output of the nomic-embed-text model.


```
-- Create table with Vector support
CREATE TABLE DemoDocuments (
    Id INT IDENTITY PRIMARY KEY,
    TextContent NVARCHAR(500),
    Embedding VECTOR(768)
);

-- Generate embeddings on the fly during INSERT
INSERT INTO DemoDocuments (TextContent, Embedding)
VALUES ('Vector search allows semantic similarity queries', 
        AI_GENERATE_EMBEDDINGS('Vector search allows semantic similarity queries' USE MODEL ollama_embeddings));

Note : Addtionally we can create an vector index for better performance.

-- Perform Semantic Search

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


```
Results return semantically related content rather than keyword matches.


<img width="509" height="326" alt="image" src="https://github.com/user-attachments/assets/062c8c82-cc15-431c-9826-4e19df5d66c2" />

### Summary :

This deployment was implemented as a Proof of Concept (POC) to demonstrate how SQL Server’s native vector capabilities can integrate with locally hosted AI models in a Kubernetes environment. The goal of the POC is to validate that semantic search can be performed entirely within an AKS cluster, without relying on external AI APIs.   
By combining SQL Server vector search, Ollama embedding models, and Kubernetes orchestration, the POC showcases a practical approach for organizations to further explore AI-enabled databases and Retrieval Augmented Generation (RAG) architectures. Running the embedding model locally also allows teams to evaluate latency, cost, and data privacy benefits before adopting external AI services.

### Benefits
- Data Sovereignty: All data and AI processing stay within your AKS cluster.
- Cost Efficiency: No per-token costs for embedding generation.
- High Performance: Localhost communication between the DB and the AI model eliminates network jitter.
- Secure: Integrated TLS encryption and persistent Azure storage.

---

<b>References :</b> https://github.com/tejasaks/PublicDemos/tree/main/SQLAICustomContainer














