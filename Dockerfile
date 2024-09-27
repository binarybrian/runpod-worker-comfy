# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 

# Install Python, git and other necessary tools
RUN apt-get update -y && apt-get install -y \
    ffmpeg \
    libgl1-mesa-dev \
    netpbm \
    python3.10 \
    python3-matplotlib \
    python3-numpy \
    python3-opencv \
    python3-piexif \
    python3-pil \
    python3-pip \
    git \
    wget \
    xvfb

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install ComfyUI dependencies
RUN python3 -m pip install --upgrade pip && \
    pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Stage 2: Download models
FROM base as downloader

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Change working directory to ComfyUI
WORKDIR /comfyui

# Download checkpoints/vae/LoRA to include in image based on model type
RUN mkdir -p models/checkpoints models/vae && \
    if [ "$MODEL_TYPE" = "sdxl" ]; then \
      wget -O models/checkpoints/sd_xl_base_1.0.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors && \
      wget -O models/vae/sdxl_vae.safetensors https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors && \
      wget -O models/vae/sdxl-vae-fp16-fix.safetensors https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors; \
    elif [ "$MODEL_TYPE" = "sd3" ]; then \
      wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/checkpoints/sd3_medium_incl_clips_t5xxlfp8.safetensors https://huggingface.co/stabilityai/stable-diffusion-3-medium/resolve/main/sd3_medium_incl_clips_t5xxlfp8.safetensors; \
    elif [ "$MODEL_TYPE" = "flux1-schnell" ]; then \
      wget -O models/unet/flux1-schnell.safetensors https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors && \
      wget -O models/clip/clip_l.safetensors https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors && \
      wget -O models/clip/t5xxl_fp8_e4m3fn.safetensors https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors && \
      wget -O models/vae/ae.safetensors https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors; \
    elif [ "$MODEL_TYPE" = "flux1-dev" ]; then \
      wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/unet/flux1-dev.safetensors https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors && \
      wget -O models/clip/clip_l.safetensors https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors && \
      wget -O models/clip/t5xxl_fp8_e4m3fn.safetensors https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors && \
      wget --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/vae/ae.safetensors https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors; \
    else \
      #wget -O models/checkpoints/sd_xl_base_1.0.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors && \
      touch models/checkpoints/no-checkpoints.txt && \
      touch models/vae/no-vae.txt; \
    fi

# Stage 3: Download nodes
FROM base as nodes

WORKDIR /comfyui

RUN git clone --recursive https://github.com/giriss/comfy-image-saver custom_nodes/comfy-image-saver && \
    git clone --recursive https://github.com/sipherxyz/comfyui-art-venture custom_nodes/comfyui-art-venture && \
    git clone --recursive https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes custom_nodes/ComfyUI_Comfyroll_CustomNodes && \
    git clone --recursive https://github.com/pythongosssss/ComfyUI-Custom-Scripts custom_nodes/ComfyUI-Custom-Scripts && \
    git clone --recursive https://github.com/hylarucoder/ComfyUI-Eagle-PNGInfo custom_nodes/ComfyUI-Eagle-PNGInfo && \
    git clone --recursive https://github.com/cubiq/ComfyUI_essentials custom_nodes/ComfyUI_essentials && \
    git clone --recursive https://github.com/ltdrdata/ComfyUI-Manager custom_nodes/ComfyUI-Manager && \
    git clone --recursive https://github.com/ssitu/ComfyUI_UltimateSDUpscale custom_nodes/ComfyUI_UltimateSDUpscale && \
    git clone --recursive https://github.com/Derfuu/Derfuu_ComfyUI_ModdedNodes custom_nodes/Derfuu_ComfyUI_ModdedNodes && \
    git clone --recursive https://github.com/jags111/efficiency-nodes-comfyui custom_nodes/efficiency-nodes-comfyui && \
    git clone --recursive https://github.com/binarybrian/LiberatedHelpers custom_nodes/LiberatedHelpers && \
    git clone --recursive https://github.com/rgthree/rgthree-comfy custom_nodes/rgthree-comfy && \
    git clone --recursive https://github.com/twri/sdxl_prompt_styler custom_nodes/sdxl_prompt_styler && \
    git clone --recursive https://github.com/binarybrian/Winston custom_nodes/Winston && \
    for dir in custom_nodes/*/; do if [ -f "$dir/requirements.txt" ]; then (cd "$dir" && pip3 install -r requirements.txt) || echo "Failed to install requirements in $dir"; fi; done;

#Stage 4: Upgrade ffmpeg
FROM base as utils

WORKDIR /

RUN wget -O ffmpeg.tar.xz https://www.johnvansickle.com/ffmpeg/old-releases/ffmpeg-6.0.1-amd64-static.tar.xz \
    && mkdir -p ffmpeg && tar --strip-components=1 -xf ffmpeg.tar.xz -C ffmpeg

# Stage 5: Final image
FROM base as final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

# Copy custom_nodes from stage 3 to the final image
COPY --from=nodes /comfyui/custom_nodes /comfyui/custom_nodes

# Copy ffmpeg from stage 4 to the final image
COPY --from=utils /ffmpeg /usr/bin

# Start the container
CMD /start.sh