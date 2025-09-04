# StudyBot 🤖📚

A **RAG-based (Retrieval-Augmented Generation) chatbot** designed to help students study using their course materials. Upload textbooks, lecture notes, PDFs, and other documents, then ask questions and receive accurate, contextual answers based on your specific course content.

## Features ✨

- 📚 **Course Management**: Organize materials by course with custom colors and descriptions
- 📄 **Document Processing**: Support for PDF and text files with automatic content extraction
- 🧠 **Dual AI Provider Support**: Choose between OpenAI GPT or Anthropic Claude models at compile time
- 🔍 **Hybrid Search**: Combines semantic similarity search with keyword matching for optimal context retrieval
- 💾 **Semantic LRU Caching**: Intelligent caching system that recognizes similar queries to improve response speed
- 💬 **Chat Interface**: Clean, modern chat interface with session management
- ⚡ **Real-time Processing**: Asynchronous document processing and embedding generation

## Prerequisites 📋

- **Elixir 1.15+** and **Erlang/OTP 26+**
- **AI Provider API Key(s)**:
  - **OpenAI API Key** - Get one from [OpenAI Platform](https://platform.openai.com)
  - **Anthropic API Key** (optional) - Get one from [Anthropic Console](https://console.anthropic.com)
- **pdftotext** command-line tool for PDF processing (from poppler-utils):
  ```bash
  # On macOS
  brew install poppler
  
  # On Ubuntu/Debian
  sudo apt-get install poppler-utils
  
  # On CentOS/RHEL
  sudo yum install poppler-utils
  ```

## Setup Instructions 🚀

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd study_bot
mix setup
```

### 2. Configure AI Provider API Keys

#### Option A: OpenAI Only (Default Configuration)
```bash
export OPENAI_API_KEY="your-openai-api-key-here"
```

#### Option B: Anthropic Claude + OpenAI (for embeddings)
```bash
export OPENAI_API_KEY="your-openai-api-key-here"        # Still needed for embeddings
export ANTHROPIC_API_KEY="your-anthropic-api-key-here"
```

To make these permanent, add them to your shell profile:
```bash
echo 'export OPENAI_API_KEY="your-openai-api-key-here"' >> ~/.zshrc
echo 'export ANTHROPIC_API_KEY="your-anthropic-api-key-here"' >> ~/.zshrc
source ~/.zshrc
```

#### Switching AI Providers

The AI provider is selected at **compile time** via configuration:

**For OpenAI (default):**
```bash
# config/config.exs already defaults to OpenAI
mix phx.server
```

**For Anthropic Claude:**
```bash
# Copy the Anthropic configuration
cp config/anthropic.exs config/dev_local.exs
mix phx.server
```

**Or modify config/config.exs directly:**
```elixir
config :study_bot,
  ai_provider: :anthropic,  # Change from :openai to :anthropic
  openai_api_key: System.get_env("OPENAI_API_KEY"),      # Still needed for embeddings
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")
```

### 3. Start the Application

```bash
mix phx.server
```

Visit [`http://localhost:4000`](http://localhost:4000) in your browser.

## AI Provider Options 🤖

StudyBot supports two AI providers that can be selected at compile time:

### OpenAI (Default)
- **Chat Model**: GPT-3.5-turbo
- **Embeddings**: text-embedding-ada-002 (1536 dimensions)
- **Pros**: Well-established, cost-effective, good performance
- **Cons**: Requires OpenAI account and credits

### Anthropic Claude
- **Chat Model**: Claude-3-Haiku (configurable to other Claude models)
- **Embeddings**: Uses OpenAI text-embedding-ada-002 (Anthropic doesn't provide embeddings)
- **Pros**: Often better at reasoning and longer conversations
- **Cons**: Requires both Anthropic AND OpenAI API keys

**Note**: Regardless of chat provider, OpenAI is always used for embeddings since Anthropic doesn't offer embedding models.

## Usage Guide 📖

### 1. Create a Course
- Click "New Course" on the homepage
- Enter course name, description, and choose a color
- Click "Create Course"

### 2. Upload Documents
- Navigate to your course and click "Docs"
- Click "Upload Documents"
- Drag and drop or select PDF/text files (max 10MB each, up to 5 at once)
- Wait for processing to complete (documents will show "Ready" status)

### 3. Start Chatting
- Go back to your course and click "Chat"
- Ask questions about your course materials
- The AI will search through your uploaded documents and provide contextual answers

## System Architecture 🏗️

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Phoenix Web   │    │   RAG System     │    │   OpenAI API    │
│   Interface     │◄──►│                  │◄──►│                 │
└─────────────────┘    │ • Text Chunking  │    │ • Embeddings    │
                       │ • Vector Search  │    │ • Chat Completion│
┌─────────────────┐    │ • Hybrid Search  │    └─────────────────┘
│   SQLite DB     │◄──►│ • LRU Cache      │    
│                 │    └──────────────────┘    
│ • Courses       │                            
│ • Documents     │    ┌─────────────────┐     
│ • Chunks        │    │   Background    │     
│ • Embeddings    │    │   Workers       │     
│ • Cache         │    │                 │     
└─────────────────┘    └─────────────────┘     
```

### Key Components:

- **Document Processing Pipeline**: Chunks documents into searchable segments and generates embeddings
- **Hybrid Search System**: Combines semantic similarity (vector search) with keyword matching
- **Semantic LRU Cache**: Caches responses with intelligent similarity matching to reduce API calls
- **Background Processing**: Asynchronous document processing and embedding generation

## Database Schema 🗃️

- **courses**: Course information and metadata
- **documents**: Uploaded files with processing status
- **document_chunks**: Text segments from documents
- **embeddings**: Vector representations for semantic search
- **chat_sessions**: Conversation history
- **cache_entries**: LRU cache with semantic similarity

## Development Commands 🛠️

```bash
# Setup and start
mix setup                    # Install deps, create DB, build assets
mix phx.server              # Start development server

# Database operations
mix ecto.migrate            # Run migrations
mix ecto.reset              # Reset database

# Code quality
mix format                  # Format code
mix compile --warnings-as-errors  # Strict compilation
mix precommit              # Run full quality check

# Testing
mix test                   # Run tests
mix test --failed         # Run only failed tests
```

## Configuration ⚙️

### Environment Variables

- `OPENAI_API_KEY`: Your OpenAI API key (always required, used for embeddings and optionally chat)
- `ANTHROPIC_API_KEY`: Your Anthropic API key (required only when using Anthropic provider)
- `PORT`: Server port (default: 4000)

### Customization

- **AI Provider**: Set `:ai_provider` in `config/config.exs` to `:openai` or `:anthropic`
- **Chat Models**: Modify `@chat_model` in the respective client modules:
  - OpenAI: `lib/study_bot/ai/openai_client.ex` (default: "gpt-3.5-turbo")
  - Anthropic: `lib/study_bot/ai/anthropic_client.ex` (default: "claude-3-haiku-20240307")
- **Embedding Model**: Change `@embedding_model` in AI client modules (always uses OpenAI)
- **Cache Settings**: Modify cache TTL and limits in `lib/study_bot/cache.ex`
- **Chunk Size**: Adjust text chunking parameters in `lib/study_bot/documents.ex`

## Troubleshooting 🔧

### Common Issues:

1. **PDF Processing Fails**
   - Ensure `pdftotext` is installed and accessible in PATH (`brew install poppler` on macOS)
   - Check PDF file is not encrypted or corrupted
   - Verify poppler-utils package is properly installed

2. **AI API Errors**
   - **OpenAI**: Verify API key is correct and has credits, check rate limits
   - **Anthropic**: Verify API key and check usage limits
   - Check internet connection
   - Ensure you have the correct API keys for your selected provider

3. **Long Processing Times**
   - Large documents take time to process
   - Check background processes with `mix run --no-halt`

4. **Database Issues**
   - Run `mix ecto.reset` to recreate database
   - Check file permissions in project directory

## Performance Notes 📈

- **Document Size**: Larger documents take more time to process and generate embeddings
- **Query Speed**: First query on new content is slower; subsequent similar queries use cache
- **Embedding Generation**: Runs asynchronously in background after document upload
- **Database**: SQLite is used for simplicity; consider PostgreSQL for production deployments

## Security Considerations 🔒

- API keys are loaded from environment variables
- No authentication system (intended for local use)
- File uploads are validated for type and size
- SQL injection protection through Ecto parameterized queries

## License 📄

This project is intended for educational and personal use. Please ensure compliance with OpenAI's usage policies when using their API.

---

**Happy Studying! 🎓**

For questions or issues, please check the logs in your terminal where you started the server.
