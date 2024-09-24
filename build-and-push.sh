#!/bin/bash
# docker login -u $DOCKERHUB_USERNAME -p $DOCKERHUB_TOKEN

MODEL_NAMES=("Qwen/Qwen2.5-0.5B-Instruct" "Qwen/Qwen2.5-1.5B-Instruct" "Qwen/Qwen2.5-3B-Instruct" "Qwen/Qwen2.5-7B-Instruct" "Qwen/Qwen2.5-0.5B-Instruct-GPTQ-Int8" "Qwen/Qwen2.5-1.5B-Instruct-GPTQ-Int8" "Qwen/Qwen2.5-3B-Instruct-GPTQ-Int8" "Qwen/Qwen2.5-7B-Instruct-GPTQ-Int8")

# 定义一个标记来检查任务是否失败
FAILED=0
for MODEL_NAME in "${MODEL_NAMES[@]}"; do
  (
    # 设置环境变量
    SERVELLM_MODEL_NAME="${MODEL_NAME}"
    SERVELLM_TAG=$(echo "$MODEL_NAME" | sed -e 's/.*\///' | tr '[:upper:]' '[:lower:]')
    # 导出环境变量
    export SERVELLM_MODEL_NAME
    export SERVELLM_TAG
    # 输出环境变量
    echo "***************"
    echo "SERVELLM_MODEL_NAME: $SERVELLM_MODEL_NAME"
    echo "SERVELLM_TAG: $SERVELLM_TAG"
    # 构建镜像并推送，如果任何命令失败，设置FAILED标记
    if ! docker compose -f docker-compose.build.yml build; then
      echo "Build failed for $MODEL_NAME"
      FAILED=1
      exit 1
    fi
    if ! docker compose -f docker-compose.build.yml push; then
      echo "Push failed for $MODEL_NAME"
      FAILED=1
      exit 1
    fi
    echo "***************"
  ) &
done
# 等待所有并发任务完成
wait
# 检查是否有失败的任务
if [ $FAILED -eq 1 ]; then
  echo "One or more builds/pushes failed."
  exit 1
else
  echo "All builds and pushes completed successfully."
fi