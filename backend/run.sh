#!/bin/bash
source /home/divansh/connections/backend/bin/activate
exec uvicorn src.server:app --port 1163 --host 0.0.0.0

