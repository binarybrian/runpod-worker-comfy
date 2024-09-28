#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

cogpath="/runpod-volume/models/CogVideo"
modelpath="/comfyui/models"
if [ -e "$cogpath" ] && [ -e "$modelpath" ]; then
  echo "Aliasing CogVideo path $cogpath to $modelpath/CogVideo";
  ln -s "$cogpath" "$modelpath/CogVideo"
else
  echo "Failed to alias missing paths $cogpath to $modelpath/CogVideo"
fi

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    echo "runpod-worker-comfy: Starting ComfyUI"
    python3 /comfyui/main.py --disable-auto-launch --disable-metadata --verbose --listen &

    echo "runpod-worker-comfy: Starting RunPod Handler"
    python3 -u /rp_handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    echo "runpod-worker-comfy: Starting ComfyUI"
    python3 /comfyui/main.py --disable-auto-launch --disable-metadata --verbose &

    echo "runpod-worker-comfy: Starting RunPod Handler"
    python3 -u /rp_handler.py
fi