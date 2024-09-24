FROM docker.io/nvidia/cuda:12.1.0-devel-ubuntu22.04 AS with-vllm
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y software-properties-common git curl && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get -y remove --purge python3.10 python3.10-minimal && \
    apt-get -y autoremove && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apt-get install -y tzdata && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y  \
        python3.12  \
        python3.12-venv  \
        python3.12-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --set python3 /usr/bin/python3.12 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /root/.cache
RUN pip install --no-cache vllm && \
    pip install --no-cache-dir git+https://github.com/huggingface/transformers && \
    pip install --no-cache-dir flash-attn --no-build-isolation

FROM docker.io/python:3.10-slim AS with-model
ARG SERVELLM_MODEL_NAME=Qwen/Qwen2-0.5B-Instruct
ENV SERVELLM_MODEL_NAME=$SERVELLM_MODEL_NAME
WORKDIR /root/.cache/huggingface/
RUN pip install --no-cache-dir --upgrade huggingface_hub && \
    # export HF_ENDPOINT=https://hf-mirror.com && \
    huggingface-cli download --resume-download $SERVELLM_MODEL_NAME

FROM with-vllm AS final
ARG SERVELLM_MODEL_NAME=Qwen/Qwen2.5-0.5B-Instruct
ENV SERVELLM_MODEL_NAME=$SERVELLM_MODEL_NAME \
    SERVELLM_MODEL_DTYPE=auto \
    SERVELLM_MODEL_TP=1 \
    GPU_MEMORY_UTILIZATION=0.9 \
    MAX_MODEL_LEN=1024 \
    PORT=8000
COPY --from=with-model /root/.cache/huggingface/ /root/.cache/huggingface/
ENTRYPOINT ["/bin/bash", "-c", "python -m vllm.entrypoints.openai.api_server --model \"$SERVELLM_MODEL_NAME\" --dtype \"$SERVELLM_MODEL_DTYPE\" -tp \"$SERVELLM_MODEL_TP\" --gpu-memory-utilization \"$GPU_MEMORY_UTILIZATION\" --max-model-len \"$MAX_MODEL_LEN\" --port \"$PORT\""]
