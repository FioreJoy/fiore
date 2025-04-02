#!/bin/bash
. bin/activate && cd src && uvicorn main:app --reload --port 1163 --host 100.97.215.85

