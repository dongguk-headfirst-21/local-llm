#!/bin/sh
set -e

echo "Pulling model: $MODEL ..."
ollama pull "$MODEL"

echo "Loading model into GPU memory (keep_alive=-1)..."
curl -sf "http://$OLLAMA_HOST/api/generate" \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"\",\"keep_alive\":-1}" \
  -o /dev/null

echo "Done. $MODEL is ready at http://ollama:11434"
