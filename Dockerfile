ARG SERVELLM_CUDA_VERSION=12.1
FROM docker.io/nvidia/cuda:${SERVELLM_CUDA_VERSION}.0-devel-ubuntu22.04 as with-cuda
ARG SERVELLM_PYTHON_VERSION=3.10
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace
RUN apt-get update && \
    apt-get install --no-install-recommends -y software-properties-common git curl && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install --no-install-recommends -y  \
        python${SERVELLM_PYTHON_VERSION}  \
        python${SERVELLM_PYTHON_VERSION}-venv  \
        python${SERVELLM_PYTHON_VERSION}-dev  \
        python3-pip  \
        python3-distutils && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${SERVELLM_PYTHON_VERSION} 1 && \
    update-alternatives --set python3 /usr/bin/python${SERVELLM_PYTHON_VERSION} && \
    python3 -m pip install --upgrade --no-cache pip && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /root/.cache

FROM with-cuda as with-vllm
ARG SERVELLM_CUDA_VERSION
#ARG SERVELLM_PYTHON_VERSION
ENV CUDA_HOME=/usr/local/cuda \
    PATH="${CUDA_HOME}/bin:${PATH}" \
    # Change this to the latest version of VLLM
    VLLM_VERSION=0.4.0.post1 \
    PYTHON_VERSION_MAJOR_MINOR=${SERVELLM_PYTHON_VERSION//./} \
    CUDA_VERSION_MAJOR_MINOR=${SERVELLM_CUDA_VERSION//./} \
    SERVELLM_CUDA_VERSION=$SERVELLM_CUDA_VERSION
RUN if [ "$SERVELLM_CUDA_VERSION" = "12.1" ]; then \
        VLLM_WHL_NAME=vllm-${VLLM_VERSION}-cp${PYTHON_VERSION_MAJOR_MINOR}-cp${PYTHON_VERSION_MAJOR_MINOR}-manylinux1_x86_64.whl ; \
    elif [ $SERVELLM_CUDA_VERSION = "11.8" ]; then \
        VLLM_WHL_NAME=vllm-${VLLM_VERSION}+cu${CUDA_VERSION_MAJOR_MINOR}-cp${PYTHON_VERSION_MAJOR_MINOR}-cp${PYTHON_VERSION_MAJOR_MINOR}-manylinux1_x86_64.whl ; \
    fi && \
    echo $VLLM_WHL_NAME && \
    pip install --no-cache https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/${VLLM_WHL_NAME}  \
        --extra-index-url https://download.pytorch.org/whl/cu${CUDA_VERSION_MAJOR_MINOR} && \
    git clone https://github.com/huggingface/transformers && \
    cd transformers && \
    pip install -e . && \
    cd .. && \
    pip install --no-cache-dir flash-attn --no-build-isolation

FROM with-vllm as with-model
ARG SERVELLM_PRE_DOWNLOAD=false
ARG SERVELLM_MODEL_NAME=Qwen/Qwen1.5-0.5B-Chat
ENV SERVELLM_MODEL_NAME=$SERVELLM_MODEL_NAME \
    SERVELLM_MODEL_DTYPE=auto \
    SERVELLM_MODEL_TP=1
RUN if [ "$SERVELLM_PRE_DOWNLOAD" = "true" ]; then \
        pip install --no-cache-dir --upgrade "huggingface_hub[hf_transfer]" && \
        export HF_HUB_ENABLE_HF_TRANSFER=1 && \
        huggingface-cli download $SERVELLM_MODEL_NAME ; \
    fi
ENTRYPOINT ["/bin/bash", "-c", "python -m vllm.entrypoints.openai.api_server --model \"$SERVELLM_MODEL_NAME\" --dtype \"$SERVELLM_MODEL_DTYPE\" -tp \"$SERVELLM_MODEL_TP\""]