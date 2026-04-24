#!/bin/bash
# 脚本功能：检查家目录下的 cirros 镜像文件并上传至 OpenStack
# 使用前请确保已加载 OpenStack 环境变量

set -e

IMAGE_FILE="$HOME/cirros-0.6.3-x86_64-disk.img"
IMAGE_NAME="cirros06"

echo "=========================================="
echo "检查 Cirros 测试镜像并上传"
echo "=========================================="

if [ -f "$IMAGE_FILE" ]; then
    echo -e "\n>>> 文件存在：$IMAGE_FILE"
    echo ">>> 开始上传镜像，名称：$IMAGE_NAME"
    openstack image create "$IMAGE_NAME" \
        --disk-format qcow2 \
        --container-format bare \
        --file "$IMAGE_FILE" \
        --public
    echo -e "\n✅ 镜像上传完成。"
    echo "当前镜像列表："
    openstack image list --name "$IMAGE_NAME"
else
    echo -e "\n❌ 错误：文件 $IMAGE_FILE 不存在。"
    echo "请先下载 Cirros 镜像到用户家目录："
    echo ""
    echo "    wget -P ~/ http://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img"
    echo ""
    exit 1
fi
