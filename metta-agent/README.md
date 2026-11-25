# MeTTa (PeTTa) CLI Agent

A CLI coding agent where **MeTTa (PeTTa)** owns the control loop, state, prompt budgeting, tool dispatch, and safety policy, **SWI-Prolog (`src/prims.pl`)** handles HTTP, shell execution, file I/O, and tag parsing, and **Qwen2.5-7B-Instruct** on a Colab T4 GPU (via Ollama + `cloudflared`) generates replies.

## Prerequisites
- SWI-Prolog 9.3+
- PeTTa installed locally (`PETTA_HOME`)
- `curl`

## Quick Start
1. Open `colab/model_server.ipynb` in Google Colab (T4 GPU) and run all cells.
2. Copy the printed `https://*.trycloudflare.com` URL.
3. Run the agent locally:
   ```bash
   export PETTA_HOME=/path/to/PeTTa
   export AGENT_LLM_URL=https://<your-tunnel>.trycloudflare.com
   chmod +x run.sh
   ./run.sh --trace